function SimulateGrid

%------------------------------------------------------------------------------%
% One-off Declarations
mpc0 = loadcase('case33mg');                 % base 33-bus microgrid case

%------------------------------------------------------------------------------%
% Import raw dataset
rawDataset = csvread('RegroupedDataset/RegroupedData.csv');

%------------------------------------------------------------------------------%
% Power Flow Analysis
untamperedVectors = [];
tamperedVectors   = [];
labels            = [];

actives   = [];
reactives = [];

% Precompute a simple normalized profile from first active column
max_active = max(rawDataset(:,1));
if max_active == 0
    max_active = 1;    % avoid division by zero
end

for j = 1:20000   % j is the time step
    % Work on a fresh copy of the case each timestep
    mpc = mpc0;

    %--------------------------------------------%
    % Split active and reactive power measurements
    tempActives   = [];
    tempReactives = [];
    Ncols = 22;   % 11 active + 11 reactive columns

    for i = 1:Ncols
        if mod(i,2) ~= 0
            tempActives   = [tempActives,   rawDataset(j,i)];
        else
            tempReactives = [tempReactives, rawDataset(j,i)];
        end
    end
    actives   = [actives;   tempActives];
    reactives = [reactives; tempReactives];

    %--------------------------------------------%
    % Set the microgrid load profile (buses 2..12)
    load_buses = 2:12;   % 11 buses

    cell = 1;
    for k = 1:length(load_buses)
        b = load_buses(k);
        mpc.bus(b,2) = 1;                     % PQ load bus
        mpc.bus(b,3) = actives(j,  cell);     % Pd (kW, scaled in case file)
        mpc.bus(b,4) = reactives(j,cell);     % Qd
        cell = cell + 1;
    end

    %--------------------------------------------%
    % Time-varying DER outputs (PV-like) at buses 6, 18, 25
    solar_factor = rawDataset(j,1) / max_active;   % normalized 0–1

    % gen rows in case33mg: 1=bus1, 2=bus6, 3=bus18, 4=bus25
    mpc.gen(2,2) = 0.3 * solar_factor;   % PV at bus 6
    mpc.gen(3,2) = 0.3 * solar_factor;   % PV at bus 18
    mpc.gen(4,2) = 0.4 * solar_factor;   % PV/storage at bus 25

    %--------------------------------------------%
    % PCC (branch 1–34) always connected (grid-connected microgrid)
    PCC_branch_idx = size(mpc.branch,1);
    mpc.branch(PCC_branch_idx,11) = 1;   % status=1 → always connected

    %--------------------------------------------%
    % Run DC power flow analysis
    results = rundcpf(mpc);

    % Skip non-converged timesteps (should be rare now)
    if ~results.success
        status = strcat(int2str(j), '/', int2str(20000), ' skipped (no convergence)');
        disp(status);
        continue;
    end

    %--------------------------------------------%
    % Create the measurement vector (microgrid injections + flows)
    realPowerInjections = results.bus(:,3);
    realPowerFlows      = results.branch(:,14);
    measurementVector   = [realPowerInjections; realPowerFlows];

    %--------------------------------------------%
    % Compute the Jacobian matrix for the bus system
    H      = makeJac(mpc);
    jacLen = length(H);

    %--------------------------------------------%
    % Save measurement vector to untamperedVectors
    measurementVector = measurementVector(1:jacLen);
    untamperedVectors = [untamperedVectors, measurementVector];

    %--------------------------------------------%
    % Decide if measurement vector is to be falsified
    r = randi([0 100], 1, 1);   % random number 0–100

    if (r < 20) && (j > 2000)
        decision = true;        % 20% chance of falsification
    else
        decision = false;
    end

    labels = [labels; decision];

    %--------------------------------------------%
    % Falsification if decided (FDIA)
    if j > 1500
        if ~decision
            % Append the untampered measurement vector
            tamperedVectors = [tamperedVectors, measurementVector];
        else
            % Simple FDIA: Jacobian-based attack
            err_vec = zeros(jacLen,1);     % no SE-based error term

            % Random attack direction
            r = randi([1 10], 1, 1);
            c = r * ones(jacLen, 1);

            % Falsified measurement vector
            za = measurementVector + H*c + err_vec;

            % Append the tampered measurement vector
            tamperedVectors = [tamperedVectors, za];
        end
    end

    status = strcat(int2str(j), '/', int2str(20000), ' simulations complete');
    disp(status)
end

untamperedVectors = transpose(untamperedVectors);
tamperedVectors   = transpose(tamperedVectors);

%------------------------------------------------------------------------------%
% Ensure output folder exists and save results
if ~exist('VectorDataset', 'dir')
    mkdir('VectorDataset');
end

writematrix(untamperedVectors, 'VectorDataset/untamperedVectorData.csv')
writematrix(tamperedVectors,   'VectorDataset/tamperedVectorData.csv')
writematrix(labels,            'VectorDataset/labelData.csv')

end
