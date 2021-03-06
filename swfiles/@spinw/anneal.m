function stat = anneal(obj, varargin)
% performs simulated annealing on the magnetic structure
%
% stat = ANNEAL(obj, 'option1', value1 ...)
%
% The function can deal only with single ion anisotropy and isotropic
% exchange interactions in 1, 2 or 3 spin dimensions.
% General and antisymmetric exchage interactions are not supported yet!
% Also the g-tensor is fixed to 2.
%
% WARNING!
% The calculated energies doesn't contain the self energy (moment coupled
% to itself), thus the energies calculated here can differ from the
% result of the sw.energy() function.
%
% Input:
%
% obj             Input object contains structural data, sw type.
%
% Options:
%
% spinDim   Dimensionality of the magnetic moments.
%               1   Ising spins
%               2   XY spins
%               3   Heisenberg spins [default]
%           For Ising (spinDim=1) and XY (spinDim=2) models only isotropic
%           exchange interaction and magnetic field can be used. For Ising
%           the direction of the spins are along x-axis, for XY model the
%           the xy-plane. Magnetic fields perpendicular to these directions
%           are omitted.
% initT     The initial temperature, can be any positive number,
%           unit is Kelvin. Default is 1.
% endT      Temperature at which to stop, can be any positive number
%           smaller than 'InitTemp', unit is Kelvin.
%           Default is 1e-3.
% cool      Generates a new temperature from the previous one.
%           Any function handle that takes a scalar as input and
%           returns a smaller but positive scalar as output.
%           Default is @(T) (.92*T).
% random    Random initial conditions, if initial spin configuration
%           is undefined (obj.mag_str.S is empty) the initial configuration
%           is automaticly random independently of the value of random.
%           Default is false.
% nMC       Number of Monte-Carlo steps per spin at each temperature
%           step to reach thermal equilibrium. Default is 100.
% nORel     Number of over-relaxation steps after every Monte-Carlo
%           steps. It rotates the spins around the direction of the local
%           field by 180deg. It is reversible and microcanonical if the
%           single ion anisotropy is zero. Default is 0.
% nStat     Number of cycles at the last temperature to calculate
%           statistical averages. It has to be smaller or equal nMC.
%           Default is 100.
% boundary  Boundary conditions of the extended unit cell.
%               'free'  Free, interactions between extedned unit cells are
%                       omitted.
%               'per'   Periodic, interactions between extended unit cells
%                       are retained.
%           Default is {'per' 'per' 'per'}.
% verbosity Controls output to the screen.
%               0   suppresses all output
%               1   gives final report only
%               2   plots temperature changes and final report [default]
% nExt      The size of the magnetic cell in number of unit cells, to
%           provide input information to 'fStat'.
%           Default is from obj.mag_str.N_ext.
% fStat     Function handle to evaluate after at the end of the
%           cooling scedule during the last nStat Monte-Carlo steps.
%           The function returns a single structure and takes fixed
%           input parameters:
%               struct = fStat(state, struct, T, E, M, nExt).
%           The function is called once before the annealing process
%           when state=1 to initialise the parameters. The function
%           is called after every Monte-Carlo steps with state=2 and
%           the output of the previous function call is assigned to
%           the input struct. fStat is called once again in the end
%           with state=3 to calculate final parameters (in the last
%           run, input struct.param contains all the annealing
%           parameters).
%           Default is <a href="matlab: doc sw_fstat">@sw_fstat</a>.
% fSub      Function to define sublattices for Monte-Carlo speedup.
%           cGraph = fSub(conn,nExt), where cGraph is a (1,nMagExt) sized
%           vector, conn is a (2,nConn) size matrix and nExt is equal to
%           'nExt'. Default is <a href="matlab: doc sw_fsub">@sw_fsub</a>
% subLat    Vector that assigns all magnetic moments into non-interacting
%           sublattices, contains a single index (1,2,3...) for every
%           magnetic moment, size is (1,nMagExt). If undefined, the
%           function defined in 'fSub' will be used to partition the
%           lattice.
% title     Gives a title string to the simulation that is saved in the
%           output.
% autoK     Bin length of the autocorrelation vector. Should be a few times
%           smaller than nMC. Default is zero, no autocorrelation function
%           is calculated.
%
% Output:
%
% stat      Struct that contains the calculated thermodynamical
%           averages and the parameters of the simulation with the
%           following fields:
%
% param     All input parameter values of the anneal function.
% obj       The copy of the input sw class obj with the final magnetic
%           structure.
% M         Components of the magnetisation after the last annealing
%           run, dimensions are [3 nMagExt].
% E         Magnetic energy of the system after the last annealing run.
% T         Final temperature of the sample.
%
% Depending on the 'fStat' parameter, additional fields are included. Using
% the default function (@sw_fstat) the following parameters are calculated:
%
% avgM      Average components of the magnetisation over nStat runs,
%           dimensions are [3 nMagExt].
% stdM      Standard deviation of the mgnetisation components over
%           nStat runs, dimensions are [3 nMagExt].
% avgE      Average system energy per spin over nStat runs, scalar.
% stdE      Standard deviation of the system energy per spin over
%           nStat runs, scalar.
% Cp        Heat capacity of the sample: (<E^2>-<E>^2)/kB/T^2.
% Chi       Magnetic susceptibility of the sample: (<M^2>-<M>^2)/kB/T.
%
%
%  Reference:
%    Kirkpatrick, S., Gelatt, C.D., & Vecchi, M.P. (1983). Optimization by
%    Simulated Annealing. _Science, 220_, 671-680.
%
% See also SPINW, SPINW.OPTMAGSTR, SW_FSUB, SW_FSTAT.
%

% save the beginning of the calculation
datestart = datestr(now);

nExt   = double(obj.mag_str.nExt);

title0 = 'Simulated annealing stat.';

inpForm.fname  = {'initT' 'endT' 'cool'        'nMC' 'nStat' 'verbosity' };
inpForm.defval = {100     1e-2   @(T) (0.92*T) 100   100     2           };
inpForm.size   = {[1 1]   [1 1]  [1 1]         [1 1] [1 1]   [1 1]       };
inpForm.soft   = {0       0      0             0      0      0           };

inpForm.fname  = [inpForm.fname  {'spinDim' 'nORel' 'nExt' 'subLat'     }];
inpForm.defval = [inpForm.defval {3         0       nExt   []           }];
inpForm.size   = [inpForm.size   {[1 1]     [1 1]   [1 3]  [1 -1]       }];
inpForm.soft   = [inpForm.soft   {0         0       0      1            }];

inpForm.fname  = [inpForm.fname  {'fStat'   'fSub'   'random' 'title'   }];
inpForm.defval = [inpForm.defval {@sw_fstat @sw_fsub false    title0    }];
inpForm.size   = [inpForm.size   {[1 1]     [1 1]    [1 1]    [1 -2]	}];
inpForm.soft   = [inpForm.soft   {0         0        0        1         }];

inpForm.fname  = [inpForm.fname  {'fineT' 'rate' 'boundary'         }];
inpForm.defval = [inpForm.defval {0       0.1    {'per' 'per' 'per'}}];
inpForm.size   = [inpForm.size   {[1 1]   [1 1]  [1 3]              }];
inpForm.soft   = [inpForm.soft   {0       0      0                  }];

inpForm.fname  = [inpForm.fname  {'autoK' }];
inpForm.defval = [inpForm.defval {0       }];
inpForm.size   = [inpForm.size   {[1 1]   }];
inpForm.soft   = [inpForm.soft   {0       }];

param = sw_readparam(inpForm,varargin{:});

if param.nStat > param.nMC
    warning('sw:anneal:wrongParam','nStat is larger than nMC, instead of the given value, nMC will be used!');
    param.nStat = param.nMC;
end

% Text output file
fid = obj.fid;

% Creates random spin directions if param.random is true.
mag_param = struct;
if param.random
    mag_param.mode = 'random';
else
    mag_param.mode = 'extend';
end
mag_param.nExt = param.nExt;

obj.genmagstr(mag_param);
M0  = obj.magstr.S;

% Produce the interaction matrices
[SS, SI] = obj.intmatrix();
% Save DM, anisotropic and general interactions into the SS.gen matrix
% Add SS.ani
zAni   = zeros(3,size(SS.ani,2));
SS.gen = [SS.gen [SS.ani(1:5,:);SS.ani(6,:);zAni;SS.ani(7,:);zAni;SS.ani(8,:)]];
% Add SS.dm
zDM    = zeros(1,size(SS.dm,2));
SS.gen = [SS.gen [SS.dm(1:5,:);zDM;-SS.dm(8,:);SS.dm(7,:);SS.dm(8,:);zDM;-SS.dm(6,:);-SS.dm(7,:);SS.dm(6,:);zDM]];
% Add dipolar interaction
SS.gen = [SS.gen SS.dip(1:14,:)];

SS     = rmfield(SS,{'ani' 'dm' 'dip'});


% Boltzmann constant.
kB      = obj.unit.kB;

% Function options.
spinDim = param.spinDim;
initT   = param.initT;
endT    = param.endT;
fineT   = param.fineT;
cool    = param.cool;
nMC     = param.nMC;
nStat   = param.nStat;
fStat   = param.fStat;
nMagExt = size(M0,2);

% Multiplyer of the moment for T=0 ground state search
Mmult = 1;

% Initial moment directions, the extra zeros are for easy indexing, size of
% M is (1,nMagExt+1).
M     = [M0 [0;0;0]];
S     = sqrt(sum(M.^2,1));
normM = [sqrt(sum(M0(1:spinDim,:).^2,1)) 1];
M     = M(1:spinDim,:).*repmat(S./normM,[spinDim 1]);

% Modify the interaction matrices according to the boundary conditions.
for ii = 1:3
    if strcmp('free',param.boundary{ii})
        SS.iso(:,SS.iso(ii,:)~=0) = [];
        SS.gen(:,SS.gen(ii,:)~=0) = [];
    end
end

% Since k_m=(0,0,0) the spins that are coupled to themself contribute with
% a constant self-energy, removing this doesn't change thermodynamical
% behaviour just shifts the zero energy.
SS.iso(:, SS.iso(4,:)==SS.iso(5,:)) = [];
SS.gen(:, SS.gen(4,:)==SS.gen(5,:)) = [];

% Calculates the energy of the initial configuration and prepares the
% anisotropy matrix. B is in units of the couplings.
switch spinDim
    case 1
        B  = SI.field(1)*obj.unit.muB*2;
        AA = SI.aniso(1,1,:);
        Ax = squeeze(AA(:,1,:));
        Ay = Ax*0;
        Az = Ay*0;
        if any(any(Ax))
            warning('sw:anneal:IsingAnisotropy','Anisotropy for Ising model is omitted.');
        end
    case 2
        B  = SI.field(1:2)'*obj.unit.muB*2;
        AA = SI.aniso(1:2,1:2,:);
        Ax = squeeze(AA(:,1,:));
        Ay = squeeze(AA(:,2,:));
        Az = Ay*0;
    case 3
        B  = SI.field'*obj.unit.muB*2;
        % TODO set g-tensor
        AA = SI.aniso;
        Ax = squeeze(AA(:,1,:));
        Ay = squeeze(AA(:,2,:));
        Az = squeeze(AA(:,3,:));
    otherwise
        error('sw:anneal:WrongData',['The dimension of the spin variable'...
            ' is wrong (spinDim = {1,2,3})!']);
end

% Checks whether there is any external field
param.isfield = any(B(:));

% Checks whether anisotropy is non-zero.
if any(AA(:))
    param.aniso = true;
else
    param.aniso = false;
end

if param.aniso && param.nORel>0
    warning('sw:anneal:OverRelaxationWarning',['Performing over-relaxation'...
        'and having non-zero single ion anisotropy would destroy detailed '...
        'balance, over-relaxation is disabled.']);
    param.nORel = 0;
end

% Initializes counters.
suc  = 0;
T    = initT;
rate = zeros(nMC,1);
E    = [];

% Initialise plot.
hFigure = sw_annealplot(T,E,rate,param,fid);

% Assing moments to sublattices for parallel calculation. There are no
% coupling between moments on the same sublattice, thus annealing can be
% calculated parallel. SSc stores the index of the sublattice, size:
% (1,nMagExt)

if isempty(param.subLat)
    SSc  = param.fSub(SS.all(4:5,:),param.nExt);
    param.subLat = SSc;
else
    SSc  = param.subLat;
end
nSub = max(SSc);

% Counts the number of neighbours of each moment taking into account only
% the isotropic exchanges.
param.isoexc = ~isempty(SS.iso);

if param.isoexc
    
    nNeigh = zeros(nMagExt,1);
    for ii = 1:nMagExt
        nNeigh(ii) = sum((SS.iso(4,:) == ii)|(SS.iso(5,:) == ii));
    end
    
    % Maximum number of neighbours
    maxNeigh = max(nNeigh);
    
    
    % Creates the SSi neigbour list of the moments in each sublattice, by
    % default it points to the last moment which is always zero. Also SSJ the
    % list of isotropic exchange values are created.
    SSi = zeros(maxNeigh,nMagExt) + (nMagExt+1);
    SSJ = zeros(maxNeigh,nMagExt);
    
    for ii = 1:nMagExt
        SSi(1:nNeigh(ii),ii) = [SS.iso(5,(SS.iso(4,:) == ii)) SS.iso(4,(SS.iso(5,:) == ii))]';
        SSJ(1:nNeigh(ii),ii) = [SS.iso(6,(SS.iso(4,:) == ii)) SS.iso(6,(SS.iso(5,:) == ii))]';
    end
end

% For general exchange values all elements of the 3x3 J-matrices has to be
% stored, the anisotropic and DM interactions are also included.
param.genexc = ~isempty(SS.gen);

if param.genexc
    
    if param.spinDim < 3
        warning('sw:anneal:DimProblem','Anisotropic exchange only works for spinDim==3!')
    end
    
    nNeighG = zeros(nMagExt,1);
    for ii = 1:nMagExt
        nNeighG(ii) = sum((SS.gen(4,:) == ii)|(SS.gen(5,:) == ii));
    end
    
    % Maximum number of neighbours
    maxNeighG = max(nNeighG);
    
    % Interaction matrices and neigbor indices
    SSiG = zeros(maxNeighG,nMagExt) + (nMagExt+1);
    SSJG = zeros(9,maxNeighG,nMagExt);
    
    % Indexes for transposing J for exchanged spins in the interaction.
    % Default is Si * J * Sj, or Sj * J' * Si has to be used.
    trIdx = reshape(reshape(1:9,[3 3])',[9 1])+5;
    for ii = 1:nMagExt
        SSiG(1:nNeighG(ii),ii) = [SS.gen(5,(SS.gen(4,:) == ii))    SS.gen(4,(SS.gen(5,:) == ii))    ]';
        SSJG(:,1:nNeighG(ii),ii) = [SS.gen(6:14,(SS.gen(4,:) == ii)) SS.gen(trIdx,(SS.gen(5,:) == ii))];
    end
    
end

% Store spin indices of each sublattice for speedup.
Sindex = zeros(nSub,nMagExt);
%for ii = 1:nSub
%    Sindex(ii,:) = (SSc == ii);
%end
Sindex(nSub*(0:nMagExt-1)+SSc) = 1;
Sindex      = logical(Sindex);

% Number of moments on each sublattice.
nElementSub = sum(Sindex,2);

% Speeds up the code by storing every sublattice data in different cells
csSSJ  = cell(nSub,1);
csSSi  = cell(nSub,1);
csSSiG = cell(nSub,1);
csSSJG = cell(nSub,1);
cAx    = cell(nSub,1);
cAy    = cell(nSub,1);
cAz    = cell(nSub,1);
cS     = cell(nSub,1);
cB     = cell(nSub,1);

for ii = 1:nSub
    sSindex    = Sindex(ii,:);
    cS{ii}    = S(sSindex);
    
    if param.isoexc
        csSSi{ii}  = reshape(SSi(:,sSindex),1,[]);
        csSSJ{ii}  = repmat(reshape(SSJ(:,sSindex),1,[]),spinDim,1);
    end
    if param.aniso
        cAx{ii}   = Ax(:,sSindex);
        cAy{ii}   = Ay(:,sSindex);
        cAz{ii}   = Az(:,sSindex);
    end
    if param.genexc
        csSSiG{ii} = reshape(SSiG(:,sSindex),1,[]);
        csSSJG{ii} = reshape(SSJG(:,:,sSindex),3,3,[]);
    end
    
    cB{ii}    = repmat(B,[1 nElementSub(ii)]);
end

% Initialize autocorrelation storage
if param.autoK > 0
    A = [];
end

% Initialise the statistical function
statT = fStat(1, struct, 0, 0, M, param.nExt);
% Monte Carlo loop until final temperature is reached.
while 1
    % Initialize autocorrelation storage
    if param.autoK > 0
        A = [A; zeros(1,param.autoK)]; %#ok<AGROW>
        C = [];
    end
    
    ETemp = sw_energyanneal(M, SS, AA, B);
    switch spinDim
        % Ising model %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        case 1
            for itry = 1:nMC
                for jsub = 1:nSub
                    % Logical vector, selecting the moments on a given
                    % sublattice [1,nMagExt]
                    sSindex = Sindex(jsub,:);
                    % Stores the interaction strength
                    % SSJ(:,sSindex) [maxNeigh, nElementSub(jsub)]
                    % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                    sSSJ = csSSJ{jsub};
                    % Stores the indices of neighbouring magnetic moments.
                    % SSi(:,sSindex) [maxNeigh, nElementSub(jsub)]
                    % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                    sSSi = csSSi{jsub};
                    % Previous moment directions of the given sublattice.
                    MOld = M(:,sSindex);
                    % F stores the molecular field acting on the moments of
                    % the jsub sublattice (exchange+external field).
                    % F [3, nElementSub(jsub)]
                    F = squeeze(sum(reshape(M(:,sSSi).*sSSJ,1, maxNeigh,[]),2))';
                    % Adds external magnetic field.
                    F = F - cB{jsub};
                    % Generate new spin directions +/-S
                    MNew = (randi([0 1],[1 nElementSub(jsub)])*2-1).*cS{jsub};
                    % Calculates the energy difference on each spin.
                    dE = (MNew-MOld).*F;
                    % aidx stores the accepted spin indices in the sublattice.
                    aidx = rand(1,nElementSub(jsub)) < exp(-dE./(kB*T(end)));
                    % sidx stores the accepted spin indices in the whole spin list.
                    sidx = false(nMagExt+1,1);
                    sidx(sSindex) = aidx;
                    % Assign the new value to the accepted spins.
                    M(:,sidx) = MNew(:,aidx);
                    % Saves the number of succesfull spin flips.
                    suc = suc + sum(aidx);
                    % Save the change of the system energy.
                    ETemp = ETemp + sum(dE(aidx));
                    
                end
                % Sotres the ratio of accepted spin flips.
                rate(itry) = suc/nMagExt;
                suc = 0;
                
                if (T(end) <= endT) && (itry>(nMC-nStat))
                    % Save the statistics  of the parameters
                    statT = fStat(2, statT, T(end), ETemp, M, param.nExt);
                end
                % calculate autocorrelation time
                if param.autoK > 0
                    % select a moment far from the boundary
                    [C, dA] = sw_autocorr(C,M(:,ceil(end/2)),param.autoK);
                    A(end,:) = A(end,:) + dA;
                end

            end
            % XY model %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        case 2
            for itry = 1:nMC
                for jsub = 1:nSub
                    
                    % Logical vector, selecting the moments on a given
                    % sublattice [1,nMagExt]
                    sSindex = Sindex(jsub,:);
                    % Stores the interaction strength
                    % SSJ(:,sSindex) [maxNeigh, nElementSub(jsub)]
                    % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                    sSSJ = csSSJ{jsub};
                    % Stores the indices of neighbouring magnetic moments.
                    % SSi(:,sSindex) [maxNeigh, nElementSub(jsub)]
                    % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                    sSSi = csSSi{jsub};
                    % Previous moment directions of the given sublattice.
                    MOld = M(:,sSindex);
                    % F stores the molecular field acting on the moments of
                    % the jsub sublattice (exchange+external field).
                    % F [3, nElementSub(jsub)]
                    F = squeeze(sum(reshape(M(:,sSSi).*sSSJ,2, maxNeigh,[]),2));
                    % Adds external magnetic field.
                    F = F - cB{jsub};
                    % Generate new spin directions, creating normal
                    % distribution of coordinates, then normalizing them.
                    phiNew = rand(1,nElementSub(jsub))*2*pi;
                    MNew = [cos(phiNew); sin(phiNew)].*repmat(cS{jsub},[2 1]);
                    if param.aniso
                        % Calculates old anisotropy field.
                        AOld = [sum(MOld.*cAx{jsub},1); sum(MOld.*cAy{jsub},1)];
                        % Calculates new anisotropy field.
                        ANew = [sum(MNew.*cAx{jsub},1); sum(MNew.*cAy{jsub},1)];
                        % Calculates the energy difference on each spin.
                        dE = sum((MNew-MOld).*F+MNew.*ANew-MOld.*AOld,1);
                    else
                        % Calculates the energy difference on each spin.
                        dE = sum((MNew-MOld).*F,1);
                    end
                    % aidx stores the accepted spin indices in the sublattice.
                    aidx = rand(1,nElementSub(jsub)) < exp(-dE./(kB*T(end)));
                    % sidx stores the accepted spin indices in the whole spin list.
                    sidx = false(nMagExt+1,1);
                    sidx(sSindex) = aidx;
                    % Assign the new value to the accepted spins.
                    M(:,sidx) = MNew(:,aidx);
                    % Saves the number of succesfull spin flips.
                    suc = suc + sum(aidx);
                    % Save the change of the system energy.
                    ETemp = ETemp + sum(dE(aidx));
                    
                end
                % Performs over-relaxation of moments.
                for jrel = 1:param.nORel
                    for jsub = 1:nSub
                        % Logical vector, selecting the moments on a given
                        % sublattice [1,nMagExt]
                        sSindex = Sindex(jsub,:);
                        % Stores the interaction strength
                        % SSJ(:,sSindex) [maxNeigh, nElementSub(jsub)]
                        % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                        % --> repmat into nSpinDim vertically
                        % --> final size [nSpinDim, maxNeigh*nElementSub(jsub)]
                        sSSJ = csSSJ{jsub};
                        % Stores the indices of neighbouring magnetic moments.
                        % SSi(:,sSindex) [maxNeigh, nElementSub(jsub)]
                        % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                        sSSi = csSSi{jsub};
                        % Previous moment directions of the given sublattice.
                        MOld = M(:,sSindex);
                        % F stores the molecular field acting on the moments of
                        % the jsub sublattice (exchange+external field).
                        % F [3, nElementSub(jsub)]
                        F = squeeze(sum(reshape(M(:,sSSi).*sSSJ,2,maxNeigh,[]),2));
                        % Adds external magnetic field.
                        F = F - cB{jsub};
                        % Flip the spins around the local field.
                        FNorm = bsxfun(@rdivide,F,sqrt(sum(F.^2,1)));
                        M(:,sSindex) = 2*bsxfun(@times,sum(MOld.*FNorm,1),FNorm)-MOld;
                    end
                end
                % Sotres the ratio of accepted spin flips.
                rate(itry) = suc/nMagExt;
                suc = 0;
                
                if (T(end) <= endT) && (itry>(nMC-nStat))
                    % Save the statistics  of the parameters
                    statT = fStat(2, statT, T(end), ETemp, M, param.nExt);
                end
                
                % calculate autocorrelation time
                if param.autoK > 0
                    % select a moment far from the boundary
                    [C, dA] = sw_autocorr(C,M(:,ceil(end/2)),param.autoK);
                    A(end,:) = A(end,:) + dA;
                end
            end
            
            % Heisenberg model %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        case 3
            for itry = 1:nMC
                for jsub = 1:nSub
                    % Logical vector, selecting the moments on a given
                    % sublattice [1,nMagExt]
                    sSindex = Sindex(jsub,:);
                    % Stores the interaction strength
                    % SSJ(:,sSindex) [maxNeigh, nElementSub(jsub)]
                    % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                    % --> repmat into nSpinDim vertically
                    % --> final size [nSpinDim, maxNeigh*nElementSub(jsub)]
                    sSSJ = csSSJ{jsub};
                    % Stores the indices of neighbouring magnetic moments.
                    % SSi(:,sSindex) [maxNeigh, nElementSub(jsub)]
                    % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                    sSSi = csSSi{jsub};
                    % Previous moment directions of the given sublattice.
                    MOld = M(:,sSindex);
                    % F stores the molecular field acting on the moments of
                    % the jsub sublattice (exchange+external field).
                    % F [3, nElementSub(jsub)]
                    if param.isoexc
                        F = squeeze(sum(reshape(sSSJ.*M(:,sSSi),3, maxNeigh,[]),2));
                    else
                        F = 0;
                    end
                    % Adds general exchange molecular field
                    if param.genexc
                        sSSJG = csSSJG{jsub};
                        F = F + squeeze(sum(reshape(permute(mmat(sSSJG,permute(M(:,csSSiG{jsub}),[1 3 2])),[1 3 2]),3, maxNeighG,[]),2));
                    end
                    % Adds external magnetic field.
                    if param.isfield
                        F = F - cB{jsub};
                    end
                    
                    
                    % Generate new spin directions, creating normal
                    % distribution of coordinates, then normalizing them.
                    randS  = randn(3,nElementSub(jsub));
                    MNew  = bsxfun(@times,randS,cS{jsub}./sqrt(sum(randS.^2)));
                    
                    % keep small S changes for T=0 ground state search
                    if T(end) < fineT
                        MNew = MOld + MNew*kB*T(end) / mean(sqrt(sum(F.^2,1)))*Mmult;
                        MNew  = bsxfun(@times,MNew,cS{jsub}./sqrt(sum(MNew.^2)));
                    end
                    
                    % doesn't work with anisotropy
                    %if T(end) == 0
                    %    MNew  = bsxfun(@times,-F,cS{jsub}./sqrt(sum(F.^2)));
                    %end
                    
                    if param.aniso
                        % Calculates old anisotropy field.
                        AOld = [sum(MOld.*cAx{jsub},1); sum(MOld.*cAy{jsub},1); sum(MOld.*cAz{jsub},1)];
                        % Calculates new anisotropy field.
                        ANew = [sum(MNew.*cAx{jsub},1); sum(MNew.*cAy{jsub},1); sum(MNew.*cAz{jsub},1)];
                        % Calculates the energy difference on each spin.
                        dE = sum((MNew-MOld).*F+MNew.*ANew-MOld.*AOld,1);
                    else
                        % Calculates the energy difference on each spin.
                        dE = sum((MNew-MOld).*F,1);
                    end
                    % aidx stores the accepted spin indices in the sublattice.
                    aidx = rand(1,nElementSub(jsub)) < exp(-dE./(kB*T(end)));
                    
                    % sidx stores the accepted spin indices in the whole spin list.
                    sidx = false(nMagExt+1,1);
                    sidx(sSindex) = aidx;
                    % Assign the new value to the accepted spins.
                    M(:,sidx) = MNew(:,aidx);
                    % Saves the number of succesfull spin flips.
                    suc = suc + sum(aidx);
                    % Save the change of the system energy.
                    ETemp = ETemp + sum(dE(aidx));
                end
                % Performs over-relaxation of moments.
                for jrel = 1:param.nORel
                    for jsub = 1:nSub
                        % Logical vector, selecting the moments on a given
                        % sublattice [1,nMagExt]
                        sSindex = Sindex(jsub,:);
                        % Stores the interaction strength
                        % SSJ(:,sSindex) [maxNeigh, nElementSub(jsub)]
                        % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                        % --> repmat into nSpinDim vertically
                        % --> final size [nSpinDim, maxNeigh*nElementSub(jsub)]
                        sSSJ = csSSJ{jsub};
                        % Stores the indices of neighbouring magnetic moments.
                        % SSi(:,sSindex) [maxNeigh, nElementSub(jsub)]
                        % --> reshape into [1, maxNeigh*nElementSub(jsub)] size
                        sSSi = csSSi{jsub};
                        % Previous moment directions of the given sublattice.
                        MOld = M(:,sSindex);
                        % F stores the molecular field acting on the moments of
                        % the jsub sublattice (exchange+external field).
                        % F [3, nElementSub(jsub)]
                        if param.isoexc
                            F = squeeze(sum(reshape(sSSJ.*M(:,sSSi),3, maxNeigh,[]),2));
                        else
                            F = 0;
                        end
                        % Adds general exchange molecular field
                        if param.genexc
                            sSSJG = csSSJG{jsub};
                            F = F + squeeze(sum(reshape(permute(mmat(sSSJG,permute(M(:,csSSiG{jsub}),[1 3 2])),[1 3 2]),3, maxNeighG,[]),2));
                        end
                        % Adds external magnetic field.
                        F = F - cB{jsub};
                        % Flip the spins around the local field.
                        FNorm = bsxfun(@rdivide,F,sqrt(sum(F.^2,1)));
                        M(:,sSindex) = 2*bsxfun(@times,sum(MOld.*FNorm,1),FNorm)-MOld;
                    end
                end
                % Stores the ratio of accepted spin flips.
                rate(itry) = suc/nMagExt;
                
                suc = 0;
                
                if (T(end) <= endT) && (itry>(nMC-nStat))
                    % Save the statistics  of the parameters
                    statT = fStat(2, statT, T(end), ETemp/nMagExt, M, param.nExt);
                end

                % calculate autocorrelation time
                if param.autoK > 0
                    % select a moment far from the boundary
                    [C, dA] = sw_autocorr(C,M(:,ceil(end/2)),param.autoK);
                    A(end,:) = A(end,:) + dA;
                end
                
            end
    end
    
    if T(end) < fineT
        % new multiplyer to keep the acceptance rate constant
        Mmult = Mmult*(1+log(param.rate/mean(rate))/-mean(abs(dE./(kB*T(end)))));
    end
    
    % Calculates the system energy at the end of the temperature step.
    E(end+1,1) = ETemp/nMagExt; %#ok<AGROW>
    % Monitor annealing process.
    sw_annealplot(T,E,rate,param,fid,hFigure);
    % End annealing process if final temperature reached.
    if T(end) <= endT
        break;
    end
    % Decreases T according to cooling schedule.
    T(end+1) = cool(T(end));              %#ok<AGROW>
end

% Send the annealing parameters
statT.kB = obj.unit.kB;
% Calculate physical properties of the system.
stat = fStat(3, statT, T(end), E(end), M, param.nExt);

% For anneal, the result is the average spin value.
obj.mag_str.F  = stat.M;
obj.mag_str.k  = [0;0;0];
stat.obj       = copy(obj);
stat.param     = param;
stat.T         = T(end);
stat.E         = ETemp/nMagExt;
stat.datestart = datestart;
stat.dateend   = datestr(now);
stat.title     = param.title;

% save autocorrelation times
if param.autoK > 0
    stat.A        = A;
end

end

function  E = sw_energyanneal(M, SS, AA, B)
% E = SW_ENERGYANNEAL(M, SS, AA, B, param) calculates the magnetic energy
% of the system, including Heisenberg exchange, single ion anisotropy and
% external magnetic field.
%
% M       Components of the magnetisation, size (spinDim, nMagExt*nT).
% SS      Structure, defining the interaction between spins, every column
%         is an interaction between two spins in the extended magnetic
%         cell: [da; db; dc; M1; M2; Jxx ...], where [da; db; dc] is the
%         lattice translation vector between the interacting spins on the
%         extended magnetic cell, [M1; M2] are the indices of the two
%         interacting spins, [Jxx...] is a column vector of the values of
%         the interaction, for Heisenberg interaction it is [Jxx=Jyy=Jzz],
%         for anisotropic exchange interaction [Jxx; Jyy; Jzz], for
%         Dzyaloshinskii-Moriya interaction [Dxy; Dxz; Dyz], for general
%         interaction matrix [Jxx; Jxy; Jxz; Jyx; Jyy; Jyz; Jzx; Jzy; Jzz].
% AA      Single ion energy matrix, size: (spinDim,spinDim,nMagExt*nT).
% B       Magnetic field, size: (1, spinDim).
%

spinDim = size(M,1);

nMagExt = size(M,2)-1;

iM  = M(:,1:nMagExt);

% Calculates anisotropy energy for XY and Heisenberg models.
if spinDim > 1
    Ml     = repmat(shiftdim(iM,-1), [spinDim 1 1]);
    Mr     = permute(Ml,[2 1 3]);
    anisoE = Ml.*AA.*Mr;
else
    anisoE = 0;
end

fieldE = -sum(B'*iM);

if ~isempty(SS.iso)
    M1  = iM(:,SS.iso(4,:));
    M2  = iM(:,SS.iso(5,:));
    excEiso   =  sum(SS.iso(6,:).*sum(M1.*M2,1),2);
else
    excEiso = 0;
end

if ~isempty(SS.gen)
    M1  = iM(:,SS.gen(4,:));
    M2  = iM(:,SS.gen(5,:));
    excEgen   =  sum(mmat(mmat(permute(M1,[3 1 2]),reshape(SS.gen(6:end,:),3,3,[])),permute(M2,[1 3 2])),3);
else
    excEgen = 0;
    
end
E = excEiso + excEgen + sum(anisoE(:)) + fieldE;

end


function [C, dA] = sw_autocorr(C,q,autoK)
% calculates the autocorrelation time

if size(C,2) < autoK+1
    C = [q C];
end
if size(C,2) == autoK+1
    C = [q C(:,1:end-1)];
    dA = sum(bsxfun(@times,q,C(:,2:end)),1);
else
    dA = 0;
end

end
