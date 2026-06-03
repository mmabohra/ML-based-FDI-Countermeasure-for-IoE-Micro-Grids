function SimulateIsland_Q

% ============================================================================
% AC Q-V DROOP FDI ATTACK SIMULATION — ISLANDED INVERTER MICROGRID
% ============================================================================
%
% Models stealthy False Data Injection (FDI) attacks that target the
% centralised Q-V droop control layer of an islanded microgrid.
%
%  SYSTEM:   Modified IEEE 33-bus distribution feeder (case33mg, 5 MVA base)
%            Bus 1  — grid-forming inverter (slack, V/f reference)
%            Bus 6, 18, 25 — DER units with Q-V droop control
%            Bus 34 + PCC branch removed upon islanding
%
%  ATTACK:   State-space FDI:  z_a = z_true + H*c
%            c injects +deltaV_attack into DER voltage magnitude states
%            -> state estimator reports inflated DER voltages
%            -> central Q dispatcher reduces Q references via droop law
%            -> real bus voltages drop  ->  risk of UVLS
%
%  DETECTION: WLS bad-data detection (BDD)
%             Threshold  tau = mu(J_true) + 3*sigma(J_true)
%             calibrated adaptively over ALL converged steps
%
%  DATASET:   VectorDataset_Droop_AC_Q/
%             All output arrays are length-consistent (post-warmup only)
%
%  BUG FIXES vs. previous version
%    1. tamperedVectors / untamperedVectors now populated ONLY after warmup
%       => all saved CSVs have identical row counts (consistent with labels)
%    2. buildMeasurementMatrix: z uses net bus injection
%       S_bus = V.*conj(Ybus*V)  [p.u.]  — consistent with H = dSbus_dV
%       (previous version incorrectly used Pd from bus matrix col 3)
%    3. bdd_tau recomputed at EVERY post-warmup step (not only attack steps)
%       => no Inf artefacts in bdd_tau_log
%    4. rng(42) seed for reproducibility
%
%  REFERENCE: Baran & Wu IEEE Trans. Power Del. 1989 (33-bus feeder)
% ============================================================================

rng(42);  % reproducibility

%% Load case and dataset
mpc0       = loadcase('case33mg');
rawDataset = csvread('RegroupedData.csv');

%% System parameters
kp    = 0.05;   % P-f droop gain        [Hz / MW]
f_nom = 50.0;   % nominal frequency     [Hz]
kq    = 0.01;   % Q-V droop gain        [p.u.V / MVAr]
V_nom = 1.0;    % nominal voltage       [p.u.]

%% Measurement noise
sigma_P = 0.001;   % active power meas. noise std   [p.u.]
sigma_Q = 0.001;   % reactive power meas. noise std [p.u.]

%% Meter placement (post-islanding: 33 buses, 32 branches)
meter_buses    = (2:33)';   % bus-injection meters at buses 2-33
meter_branches = (1:32)';   % branch-flow meters on branches 1-32

%% Load normalisation
max_active = max(rawDataset(:,1));
if max_active == 0; max_active = 1; end

%% DER topology (fixed)
der_bus_nums = [6, 18, 25];   % DER bus indices
der_gen_rows = [2,  3,  4];   % row indices in mpc.gen

%% BDD calibration
J_true_samples = [];   % baseline WLS residuals (all converged steps)
bdd_tau        = Inf;  % adaptive threshold (set after warmup)

%% Output arrays — ALL same length = post-warmup converged steps
labels            = [];
voltDeviations    = [];  % designed injection delta_V_attack [p.u.]  (0 = normal)
V_perceived_log   = [];  % attacker's perceived DER voltage [p.u.]
bddResults        = [];  % 1 = stealthy (J_att < tau), 0 = detected
J_attack_log      = [];  % WLS residual under falsified measurements
J_true_log        = [];  % WLS residual under true measurements
bdd_tau_log       = [];  % BDD threshold at each post-warmup step
delta_V_real_log  = [];  % signed min voltage deviation: V_min - V_nom [p.u.]
Q_ref_log         = [];  % nominal Q setpoints [MVAr],  n x 3
Q_att_log         = [];  % attacked Q setpoints [MVAr], n x 3
ls_event_log       = {};  % load-shedding event: 'None','UVLS','OVLS','Fail'
untamperedVectors  = [];  % true measurement vectors              (post-warmup)
tamperedVectors    = [];  % true or falsified meas. vectors       (post-warmup)
% ── Non-stealthy baseline (for BDD comparison figure) ──────────────────────
% For each attack step we also compute a naive Gaussian-noise attack of
% identical perturbation norm. NOT in col(H) => BDD detects it.
J_naive_log        = [];  % WLS residual under naive (random-noise) attack
naive_detected_log = [];  % 1 = BDD catches naive attack, 0 = misses

%% Simulation settings
numSteps     = 5000;
warmup_steps = 500;     % BDD calibration-only phase
attack_prob  = 0.20;    % Bernoulli attack probability (post-warmup)

fprintf('\n=== Q-V Droop FDI | %d steps | Warmup: %d | Attack prob: %.0f%% ===\n\n', ...
    numSteps, warmup_steps, attack_prob*100);

% ── Parameter Justification Table ─────────────────────────────────────────
fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║              SIMULATION PARAMETER JUSTIFICATION                     ║\n');
fprintf('╠══════════════╦══════════════╦════════════════════════════════════════╣\n');
fprintf('║ Parameter    ║ Value        ║ Justification / Source                 ║\n');
fprintf('╠══════════════╬══════════════╬════════════════════════════════════════╣\n');
fprintf('║ kq           ║ 0.01 p.u/MVAr║ Within 0.005-0.05 range for LV        ║\n');
fprintf('║              ║              ║ microgrids [Mahmood et al., IEEE TSG   ║\n');
fprintf('║              ║              ║ 2015; Guerrero et al., IEEE TIE 2011]  ║\n');
fprintf('╠══════════════╬══════════════╬════════════════════════════════════════╣\n');
fprintf('║ kp           ║ 0.05 Hz/MW   ║ Standard P-f droop for 5 MVA islanded  ║\n');
fprintf('║              ║              ║ inverter MG [Bevrani, Robust Power Sys  ║\n');
fprintf('║              ║              ║ Frequency Control, Springer 2014]      ║\n');
fprintf('╠══════════════╬══════════════╬════════════════════════════════════════╣\n');
fprintf('║ dV_attack    ║ 0.05-0.10    ║ Targets the ±5%% operational voltage    ║\n');
fprintf('║              ║ p.u.         ║ band (IEC 61000-3-3); exceeding this   ║\n');
fprintf('║              ║              ║ band provokes UVLS relay action        ║\n');
fprintf('╠══════════════╬══════════════╬════════════════════════════════════════╣\n');
fprintf('║ sigma_P,Q    ║ 0.001 p.u.   ║ IEC 62053-22 Class 0.5S smart meter:   ║\n');
fprintf('║              ║              ║ 0.5%% full-scale => ~0.001 p.u. at 5MVA ║\n');
fprintf('╠══════════════╬══════════════╬════════════════════════════════════════╣\n');
fprintf('║ Attack prob  ║ 20%%          ║ Consistent with probabilistic attack    ║\n');
fprintf('║              ║              ║ models in Liang et al., IEEE TSG 2017  ║\n');
fprintf('║              ║              ║ and Hu et al., IEEE TSG 2023           ║\n');
fprintf('╠══════════════╬══════════════╬════════════════════════════════════════╣\n');
fprintf('║ BDD tau      ║ mu+3*sigma   ║ Empirical 3-sigma rule; corresponds    ║\n');
fprintf('║              ║              ║ to ~0.3%% false-alarm rate under        ║\n');
fprintf('║              ║              ║ Gaussian noise assumption              ║\n');
fprintf('╠══════════════╬══════════════╬════════════════════════════════════════╣\n');
fprintf('║ Warmup steps ║ 500          ║ Sufficient for tau convergence:        ║\n');
fprintf('║              ║              ║ std(J_true) stabilises within ~200 obs ║\n');
fprintf('╚══════════════╩══════════════╩════════════════════════════════════════╝\n\n');

for j = 1:numSteps

    %% A — Assign loads from dataset
    Ncols       = 22;
    tempActives   = rawDataset(j, 1:2:Ncols);
    tempReactives = rawDataset(j, 2:2:Ncols);
    load_buses    = 2:12;
    total_load_P  = 0;

    mpc = mpc0;
    for k = 1:length(load_buses)
        b = load_buses(k);
        mpc.bus(b, 2) = 1;               % PQ bus
        mpc.bus(b, 3) = tempActives(k);  % Pd [kW -> later divided]
        mpc.bus(b, 4) = tempReactives(k);
        total_load_P  = total_load_P + tempActives(k);
    end

    %% B — Island: remove upstream grid connection
    mpc.bus(end, :)    = [];
    mpc.branch(end, :) = [];

    %% C — Configure DERs
    solar_factor  = rawDataset(j, 1) / max_active;
    total_load_MW = total_load_P / 1000;
    required_gen  = total_load_MW * 1.1;   % 10 % spinning reserve

    mpc.bus(1, 2)  = 3;
    mpc.gen(1, 2)  = required_gen * 0.4;
    mpc.gen(1, 9)  = required_gen * 3;

    P_ref_der = zeros(1, 3);
    Q_ref_der = zeros(1, 3);
    for g = 1:3
        P_ref_der(g)                    = required_gen * 0.2 * solar_factor;
        mpc.gen(der_gen_rows(g), 2)     = max(0.01, P_ref_der(g));
        mpc.gen(der_gen_rows(g), 9)     = required_gen * 3;
        mpc.gen(der_gen_rows(g), [4,5]) = [0.5, -0.5];  % Q limits [MVAr]
        mpc.gen(der_gen_rows(g), 3)     = 0;
    end

    %% D — Nominal Q-V droop power flow
    [results, ~] = droopVoltagePowerFlowRobust( ...
        mpc, kp, f_nom, kq, V_nom, P_ref_der, Q_ref_der, ...
        der_gen_rows, der_bus_nums, 10);

    if ~results.success
        if mod(j, 100) == 0
            fprintf('[SKIP %4d/%d] Droop PF did not converge\n', j, numSteps);
        end
        continue;
    end

    %% E — Build measurement matrix H and true measurement vector z_true
    if ~isfield(results, 'baseMVA'); continue; end
    [H, z_true] = buildMeasurementMatrix(results, meter_buses, meter_branches);

    %% F — Update BDD calibration baseline (ALL converged steps incl. warmup)
    [~, ~, J_this_true] = checkBDD(H, z_true, z_true, sigma_P, sigma_Q, Inf);
    J_true_samples = [J_true_samples; J_this_true];

    %% WARMUP — BDD calibration only; no dataset logging
    if j <= warmup_steps
        if mod(j, 100) == 0
            fprintf('[WARMUP  %4d/%d]  J_true = %.4f  |  samples = %d\n', ...
                j, numSteps, J_this_true, length(J_true_samples));
        end
        continue;
    end

    %% POST-WARMUP: recompute BDD threshold every step
    bdd_tau = mean(J_true_samples) + 3 * std(J_true_samples);

    %% Converged Q references (pre-attack)
    Q_ref_converged = results.gen(der_gen_rows, 3)';   % 1 x 3 [MVAr]

    %% G — Attack decision
    isAttacked = (rand() < attack_prob);

    %% Always log true measurements
    untamperedVectors = [untamperedVectors, z_true];

    if isAttacked
        % ─────────────────────────────────────────────────────────────
        % ATTACK BRANCH
        % Inflate perceived DER voltages by deltaV in [0.05, 0.10] p.u.
        %   -> droop law:  Q_new = Q_ref + (V_nom - V_perceived) / kq
        %   -> V_perceived > V_nom  =>  Q_new < Q_ref  =>  V drops
        % ─────────────────────────────────────────────────────────────

        delta_V_attack = 0.05 + rand() * 0.05;    % injection magnitude [p.u.]
        V_perceived    = V_nom + delta_V_attack;

        % Stealthy FDI vector:  z_a = z_true + H*c
        % c perturbs DER Vm states in the WLS state estimator
        nbus     = size(results.bus, 1);   % 33 after islanding
        n_states = size(H, 2);             % 2*nbus - 1 = 65
        c = zeros(n_states, 1);
        for b_idx = 1:length(der_bus_nums)
            vmag_idx = (nbus - 1) + der_bus_nums(b_idx);
            if vmag_idx <= n_states
                c(vmag_idx) = delta_V_attack;
            end
        end
        za = z_true + H * c;   % stealthy: J(za) ≈ J(z_true) by construction

        % Verify BDD bypass
        [is_stealthy, J_attack, J_att_true] = checkBDD(H, z_true, za, ...
            sigma_P, sigma_Q, bdd_tau);

        % ── Non-stealthy baseline: same perturbation NORM, random direction ──
        % A naive attacker injects Gaussian noise instead of using H*c.
        % Because it is NOT in the column space of H, the WLS estimator
        % cannot absorb it — the residual J_naive >> tau.
        Hc_norm  = norm(H * c);          % match the L2 norm of the stealthy injection
        eta      = randn(length(z_true), 1);
        eta      = eta / norm(eta) * Hc_norm;   % same magnitude, random direction
        z_naive  = z_true + eta;
        [~, J_naive, ~] = checkBDD(H, z_true, z_naive, sigma_P, sigma_Q, bdd_tau);
        naive_caught = (J_naive >= bdd_tau);

        % Reconstruct attacker's false state estimate
        sigma_vec = repmat(sigma_P, length(z_true), 1);
        W_bdd     = diag(1 ./ (sigma_vec.^2));
        HtWH      = H' * W_bdd * H + 1e-8 * eye(n_states);
        x_hat_att = HtWH \ (H' * W_bdd * za);

        Vm_att       = max(x_hat_att(nbus:end), 0.5);
        V_ders_att   = Vm_att(der_bus_nums);   % inflated Vm at DER buses

        % Compute attacked Q setpoints
        Q_ref_attacked = zeros(1, length(der_gen_rows));
        for g_atk = 1:length(der_gen_rows)
            delta_Q  = (V_nom - V_ders_att(g_atk)) / kq;  % negative (reduce Q)
            new_Qset = Q_ref_converged(g_atk) + delta_Q;
            Qmax = mpc.gen(der_gen_rows(g_atk), 4);
            Qmin = mpc.gen(der_gen_rows(g_atk), 5);
            Q_ref_attacked(g_atk) = max(Qmin, min(new_Qset, Qmax));
        end

        % Re-run droop PF with compromised Q references
        mpc_attacked = mpc;
        for g_atk = 1:length(der_gen_rows)
            mpc_attacked.gen(der_gen_rows(g_atk), 3) = Q_ref_attacked(g_atk);
        end
        [results_attacked, ~] = droopVoltagePowerFlowRobust( ...
            mpc_attacked, kp, f_nom, kq, V_nom, P_ref_der, Q_ref_attacked, ...
            der_gen_rows, der_bus_nums, 10);

        % Real voltage impact
        if results_attacked.success
            V_all  = results_attacked.bus(:, 8);
            delta_V_real = min(V_all) - V_nom;   % negative = voltage drop
            ls_event = 'None';
            if delta_V_real        < -0.10; ls_event = 'UVLS'; end
            if max(V_all) - V_nom  >  0.10; ls_event = 'OVLS'; end
        else
            delta_V_real = NaN;
            ls_event     = 'Fail';
        end

        % Log
        labels            = [labels;            1];
        voltDeviations    = [voltDeviations;    delta_V_attack];
        V_perceived_log   = [V_perceived_log;   V_perceived];
        bddResults        = [bddResults;        double(is_stealthy)];
        J_attack_log      = [J_attack_log;      J_attack];
        J_true_log        = [J_true_log;        J_att_true];
        bdd_tau_log       = [bdd_tau_log;       bdd_tau];
        delta_V_real_log  = [delta_V_real_log;  delta_V_real];
        Q_ref_log         = [Q_ref_log;         Q_ref_converged];
        Q_att_log         = [Q_att_log;         Q_ref_attacked];
        ls_event_log{end+1} = ls_event;
        tamperedVectors   = [tamperedVectors,   za];
        J_naive_log        = [J_naive_log;       J_naive];
        naive_detected_log = [naive_detected_log; double(naive_caught)];

        fprintf('[ATTACK  %4d/%d]  dV_inj=+%.3f  dV_real=%+.4f p.u.  J_fdi=%.1f  J_naive=%.1f  tau=%.1f  %s\n', ...
            j, numSteps, delta_V_attack, delta_V_real, J_attack, J_naive, bdd_tau, ls_event);

    else
        % ─────────────────────────────────────────────────────────────
        % NORMAL OPERATION BRANCH
        % ─────────────────────────────────────────────────────────────
        V_ders        = results.bus(der_bus_nums, 8);
        delta_V_normal = min(V_ders) - V_nom;

        labels            = [labels;            0];
        voltDeviations    = [voltDeviations;    0];
        V_perceived_log   = [V_perceived_log;   V_nom];
        bddResults        = [bddResults;        1];
        J_attack_log      = [J_attack_log;      J_this_true];
        J_true_log        = [J_true_log;        J_this_true];
        bdd_tau_log       = [bdd_tau_log;       bdd_tau];
        delta_V_real_log  = [delta_V_real_log;  delta_V_normal];
        Q_ref_log         = [Q_ref_log;         Q_ref_converged];
        Q_att_log         = [Q_att_log;         Q_ref_converged];
        ls_event_log{end+1} = 'None';
        tamperedVectors   = [tamperedVectors,   z_true];

        if mod(j - warmup_steps, 500) == 0
            fprintf('[NORMAL  %4d/%d]  V_min=%.4f p.u.  J=%.4f  tau=%.4f\n', ...
                j, numSteps, min(V_ders), J_this_true, bdd_tau);
        end
    end
end

%% Save dataset
outDir = 'VectorDataset_Droop_AC_Q';
if ~exist(outDir, 'dir'); mkdir(outDir); end

writematrix(transpose(untamperedVectors),  fullfile(outDir,'untamperedVectorData.csv'));
writematrix(transpose(tamperedVectors),    fullfile(outDir,'tamperedVectorData.csv'));
writematrix(labels,           fullfile(outDir,'labelData.csv'));
writematrix(voltDeviations,   fullfile(outDir,'voltDeviations.csv'));
writematrix(V_perceived_log,  fullfile(outDir,'voltPerceived.csv'));
writematrix(bddResults,       fullfile(outDir,'bddResults.csv'));
writematrix(J_attack_log,     fullfile(outDir,'J_attack.csv'));
writematrix(J_true_log,       fullfile(outDir,'J_true.csv'));
writematrix(bdd_tau_log,      fullfile(outDir,'bdd_tau.csv'));
writematrix(delta_V_real_log, fullfile(outDir,'delta_V_real.csv'));
writematrix(Q_ref_log,        fullfile(outDir,'Q_ref_converged.csv'));
writematrix(Q_att_log,        fullfile(outDir,'Q_attacked.csv'));
writecell(ls_event_log',      fullfile(outDir,'ls_events.csv'));
writematrix(J_naive_log,      fullfile(outDir,'J_naive.csv'));
writematrix(naive_detected_log, fullfile(outDir,'naive_detected.csv'));

n_saved = length(labels);
fprintf('\nDataset saved: %d rows in all output CSVs.\n', n_saved);

%% Summary
attack_idx = find(labels == 1);
normal_idx = find(labels == 0);
n_att = length(attack_idx);
n_nom = length(normal_idx);

fprintf('\n========================================================\n');
fprintf('  REACTIVE FDI SIMULATION RESULTS  (Q-V Droop)\n');
fprintf('========================================================\n');
fprintf('Post-warmup steps logged :  %d\n', n_saved);
fprintf('Attack steps             :  %d  (%.1f%%)\n', n_att, 100*n_att/n_saved);
fprintf('Normal steps             :  %d  (%.1f%%)\n', n_nom, 100*n_nom/n_saved);
fprintf('Final BDD threshold tau  :  %.4f\n', bdd_tau);

if n_att > 0
    dv_des   = voltDeviations(attack_idx);
    dv_real  = delta_V_real_log(attack_idx);
    dv_valid = dv_real(~isnan(dv_real));
    n_stlth  = sum(bddResults(attack_idx));
    ls_att   = ls_event_log(attack_idx);

    fprintf('\n[ Stealthiness — FDI vs. Naive Baseline ]\n');
    n_stlth       = sum(bddResults(attack_idx));
    n_naive_caught = sum(naive_detected_log);
    fprintf('FDI stealthy (J_att < tau) :  %d / %d  (%.1f%%)\n', ...
        n_stlth, n_att, 100*n_stlth/n_att);
    fprintf('Naive detected (J_nv > tau):  %d / %d  (%.1f%%)\n', ...
        n_naive_caught, n_att, 100*n_naive_caught/n_att);
    fprintf('=> BDD evasion advantage   :  %.1f%%\n', ...
        100*n_stlth/n_att - 100*(1 - n_naive_caught/n_att));

    fprintf('\n[ Voltage Impact ]\n');
    fprintf('Mean designed dV_inject  :  +%.4f p.u.\n', mean(dv_des));
    fprintf('Mean real DV_min         :  %+.4f p.u.\n', mean(dv_valid));
    fprintf('Mean |DV_min|            :   %.4f p.u.\n', mean(abs(dv_valid)));
    fprintf('Max  |DV_min|            :   %.4f p.u.\n', max(abs(dv_valid)));

    fprintf('\n[ Load Shedding ]\n');
    fprintf('UVLS events              :  %d  (%.1f%%)\n', ...
        sum(strcmp(ls_att,'UVLS')), 100*sum(strcmp(ls_att,'UVLS'))/n_att);
    fprintf('OVLS events              :  %d  (%.1f%%)\n', ...
        sum(strcmp(ls_att,'OVLS')), 100*sum(strcmp(ls_att,'OVLS'))/n_att);
    fprintf('Convergence failures     :  %d  (%.1f%%)\n', ...
        sum(strcmp(ls_att,'Fail')), 100*sum(strcmp(ls_att,'Fail'))/n_att);
end
fprintf('========================================================\n');
fprintf('Dataset  ->  %s/\n', outDir);
end


% ============================================================================
%  HELPER FUNCTIONS
% ============================================================================

function [results, delta_V_actual] = droopVoltagePowerFlowRobust( ...
        mpc, ~, ~, kq, V_nom, ~, ~, der_gen_rows, der_bus_nums, max_iter)
% Iterative Q-V droop loop with damped Q update and slack redistribution.
% Damping factor alpha = 0.4 prevents Q oscillation.

    alpha = 0.4;
    opt   = mpoption('verbose', 0, 'out.all', 0);

    results = runpf(mpc, opt);
    if ~results.success
        delta_V_actual = NaN;
        return;
    end

    V_prev = results.bus(der_bus_nums, 8);

    for iter = 1:max_iter
        % Droop update (damped)
        for g_idx = 1:length(der_gen_rows)
            g     = der_gen_rows(g_idx);
            V_m   = results.bus(der_bus_nums(g_idx), 8);
            new_Q = mpc.gen(g,3) + alpha*(V_nom - V_m)/kq;
            mpc.gen(g,3) = max(mpc.gen(g,5), min(new_Q, mpc.gen(g,4)));
        end

        % Slack overload redistribution
        if abs(results.gen(1,2)) > mpc.gen(1,9)
            excess = results.gen(1,2) - mpc.gen(1,9)*sign(results.gen(1,2));
            mpc.gen(der_gen_rows,2) = mpc.gen(der_gen_rows,2) + excess*0.35;
        end

        results = runpf(mpc, opt);
        if ~results.success
            delta_V_actual = NaN;
            return;
        end

        V_new = results.bus(der_bus_nums, 8);
        if max(abs(V_new - V_prev)) < 1e-5; break; end
        V_prev = V_new;
    end

    if results.success
        delta_V_actual = min(results.bus(der_bus_nums,8)) - V_nom;
    else
        delta_V_actual = NaN;
    end
end


function [H, z] = buildMeasurementMatrix(results, meter_buses, meter_branches)
% WLS measurement matrix H and measurement vector z for AC state estimation.
%
% Measurements: [P_inj; Q_inj; P_flow; Q_flow]
% States:       [Va_2,...,Va_n, Vm_1,...,Vm_n]   (polar, 2n-1 unknowns)
%
% FIX: z uses net bus injection  S_bus = V.*conj(Ybus*V)  [p.u.]
% which is consistent with H = dSbus/d[Va,Vm].
% Previous version incorrectly used Pd (load demand) from bus col 3.

    [Ybus, Yf, Yt] = makeYbus(results.baseMVA, results.bus, results.branch);
    V = results.bus(:,8) .* exp(1j * results.bus(:,9) * pi/180);

    [dSbus_dVm, dSbus_dVa]   = dSbus_dV(Ybus, V);
    [dSf_dVa, dSf_dVm, ~, ~] = dSbr_dV(results.branch, Yf, Yt, V);

    nbus       = size(results.bus, 1);
    angle_cols = 2:nbus;   % theta_2 ... theta_n   (n-1 states)
    mag_cols   = 1:nbus;   % Vm_1   ... Vm_n       (n   states)

    H_Pinj  = [real(dSbus_dVa(meter_buses,   angle_cols)), real(dSbus_dVm(meter_buses,   mag_cols))];
    H_Qinj  = [imag(dSbus_dVa(meter_buses,   angle_cols)), imag(dSbus_dVm(meter_buses,   mag_cols))];
    H_Pflow = [real(dSf_dVa(meter_branches,  angle_cols)), real(dSf_dVm(meter_branches,  mag_cols))];
    H_Qflow = [imag(dSf_dVa(meter_branches,  angle_cols)), imag(dSf_dVm(meter_branches,  mag_cols))];
    H = [H_Pinj; H_Qinj; H_Pflow; H_Qflow];

    % Net bus injection [p.u.] — consistent with H
    S_bus = V .* conj(Ybus * V);
    P_inj = real(S_bus(meter_buses));
    Q_inj = imag(S_bus(meter_buses));

    % Branch flows from-end [MW -> p.u.]
    P_flow = results.branch(meter_branches, 14) / results.baseMVA;
    Q_flow = results.branch(meter_branches, 15) / results.baseMVA;

    z = [P_inj; Q_inj; P_flow; Q_flow];
end


function [is_stealthy, J_attack, J_true] = checkBDD(H, z_true, z_attacked, ...
        sigma_P, sigma_Q, tau)
% WLS chi-squared residual test.
% For a stealthy attack (z_a = z + H*c):  J_attack = J_true  theoretically.
% Tiny numerical differences arise from floating-point regularisation.

    n_meas   = length(z_true);
    n_states = size(H, 2);

    half      = floor(n_meas / 2);
    sigma_vec = [repmat(sigma_P, half, 1); repmat(sigma_Q, n_meas-half, 1)];
    W         = diag(1 ./ sigma_vec.^2);

    HtWH = H'*W*H;
    if rcond(HtWH) < 1e-12
        HtWH = HtWH + 1e-8 * eye(n_states);
    end

    x_a = HtWH \ (H'*W*z_attacked);
    r_a = z_attacked - H*x_a;
    J_attack = r_a' * W * r_a;

    x_t = HtWH \ (H'*W*z_true);
    r_t = z_true - H*x_t;
    J_true = r_t' * W * r_t;

    is_stealthy = (J_attack < tau);
end