function SimulateIsland

% ISLANDED MODE: Microgrid operates autonomously without external grid

% One-off Declarations
mpc0 = loadcase('case33mg');

% Import raw dataset
rawDataset = csvread('RegroupedDataset/RegroupedData.csv');

% Power Flow Analysis
untamperedVectors = [];
tamperedVectors   = [];
labels            = [];

actives   = [];
reactives = [];

% Precompute a simple normalized profile from first active column
max_active = max(rawDataset(:,1));
if max_active == 0
    max_active = 1;
end

for j = 1:20000
    % Work on a fresh copy of the case each timestep
    mpc = mpc0;

    % Split active and reactive power measurements
    tempActives   = [];
    tempReactives = [];
    Ncols = 22;

    for i = 1:Ncols
        if mod(i,2) ~= 0
            tempActives   = [tempActives,   rawDataset(j,i)];
        else
            tempReactives = [tempReactives, rawDataset(j,i)];
        end
    end
    actives   = [actives;   tempActives];
    reactives = [reactives; tempReactives];

    % Set the microgrid load profile (buses 2..12)
    load_buses = 2:12;

    cell = 1;
    total_load_P = 0;
    for k = 1:length(load_buses)
        b = load_buses(k);
        mpc.bus(b,2) = 1;
        mpc.bus(b,3) = actives(j,  cell);
        mpc.bus(b,4) = reactives(j,cell);
        total_load_P = total_load_P + actives(j, cell);
        cell = cell + 1;
    end

    % ISLANDED MODE: Remove external grid
    mpc.bus(34,:) = [];
    mpc.branch(end,:) = [];

    % ISLANDED MODE: Configure DER generation
    solar_factor = rawDataset(j,1) / max_active;

    total_load_MW = total_load_P / 1000;
    required_gen = total_load_MW * 1.1;

    % Bus 1: Controllable generator (slack bus)
    mpc.bus(1,2) = 3;
    mpc.gen(1,2) = required_gen * 0.4;
    mpc.gen(1,9) = required_gen * 2;

    % Solar PV (time-varying)
    mpc.gen(2,2) = required_gen * 0.2 * solar_factor;
    mpc.gen(3,2) = required_gen * 0.2 * solar_factor;
    mpc.gen(4,2) = required_gen * 0.2 * solar_factor;

    % Ensure minimum generation
    min_gen = 0.01;
    for g = 1:4
        mpc.gen(g,2) = max(mpc.gen(g,2), min_gen);
    end

    % Run DC power flow analysis
    results = rundcpf(mpc);

    % Skip non-converged timesteps
    if ~results.success
        status = strcat(int2str(j), '/', int2str(20000), ' skipped (no convergence - islanded)');
        disp(status);
        continue;
    end

    % Create the measurement vector
    realPowerInjections = results.bus(:,3);
    realPowerFlows      = results.branch(:,14);
    measurementVector   = [realPowerInjections; realPowerFlows];

    % Compute the Jacobian matrix
    H      = makeJac(mpc);
    jacLen = length(H);

    % Save measurement vector
    measurementVector = measurementVector(1:jacLen);
    untamperedVectors = [untamperedVectors, measurementVector];

    % Decide if measurement vector is to be falsified
    r = randi([0 100], 1, 1);

    if (r < 20) && (j > 2000)
        decision = true;
    else
        decision = false;
    end

    labels = [labels; decision];

    % Falsification if decided (FDIA)
    if j > 1500
        if ~decision
            tamperedVectors = [tamperedVectors, measurementVector];
        else
            err_vec = zeros(jacLen,1);
            r = randi([1 10], 1, 1);
            c = r * ones(jacLen, 1);
            za = measurementVector + H*c + err_vec;
            tamperedVectors = [tamperedVectors, za];
        end
    end

    status = strcat(int2str(j), '/', int2str(20000), ' simulations complete (ISLANDED)');
    disp(status)
end

untamperedVectors = transpose(untamperedVectors);
tamperedVectors   = transpose(tamperedVectors);

% Save results
if ~exist('VectorDataset_Islanded', 'dir')
    mkdir('VectorDataset_Islanded');
end

writematrix(untamperedVectors, 'VectorDataset_Islanded/untamperedVectorData.csv')
writematrix(tamperedVectors,   'VectorDataset_Islanded/tamperedVectorData.csv')
writematrix(labels,            'VectorDataset_Islanded/labelData.csv')

disp('==============================================');
disp('ISLANDED MODE SIMULATION COMPLETE');
disp('==============================================');
disp(['Total timesteps processed: ', int2str(length(labels))]);
disp(['Convergence rate: ', num2str(100*length(labels)/20000, '%.1f'), '%']);
disp(['Outputs saved to: VectorDataset_Islanded/']);

end
