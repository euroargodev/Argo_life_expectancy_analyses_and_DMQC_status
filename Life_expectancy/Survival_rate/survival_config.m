% CONFIG_survival_rate
% plots survival rates depending on config values for a given config 
% parameter (given in number of cycles, vertical_km and float age)
%
% Input
% - list_dir: path to floats list. Floats list should contains at least WMO
%       and STATUS (list from jcommops web site)
% - dac_dir: path to gdac
% - config_param: Name of configuration parameter to be analysed
% - sample_size_limit: only config parameter values used by a number of
%       floats > sample_size_limit will be plot
% - output_folder: path to output folder
%
% Output
% - Figures with survival rates depending on number of cycles, vertical km 
%       and float age 
%
% Auxiliary functions:
%    read_csv
%    get_floats_filespath
%    get_floats_data_gdac
%    calculate_CyclePeriod
%    calculate_CTDPoints
%    get_vertical_km_multiprof
%    format_data_for_plotting
%
% NOTES
% (1) Using as input config_param = {'CONFIG_CTDPoints_NUMBER'} the
% script calculates the number of theoretical CTD points per profile using
% the function calculate_CTDPoints
%
% AUTHOR: Andrea Garcia Juan, Euro-Argo ERIC
%         (andrea.garcia.juan@euro-argo.eu)
%
% Modified on 2020/11/10 by Luca Arduini


clear variables
close all


% add paths (packages and auxiliary functions)
addpath /home1/datahome/co_arg/larduini/Andrea/updated_funtions/seawater
addpath /home1/datahome/co_arg/larduini/Andrea/updated_funtions/M_Map 
addpath /home1/datahome/co_arg/larduini/Andrea/updated_funtions/MyTools % all functions I developed
addpath /home1/datahome/co_arg/larduini/Andrea/updated_funtions/export_fig-master % export a matlab figure
addpath /home1/datahome/co_arg/larduini/Andrea/updated_funtions/addaxis % more than 2 y axis in a figure
addpath /home1/datahome/co_arg/larduini/Andrea/updated_funtions/flexLegend/legendflex % more than 1 column in legend
addpath /home1/datahome/co_arg/larduini/Andrea/updated_funtions/flexLegend/setgetpos_V1.2
addpath /home1/datahome/co_arg/larduini/Andrea/updated_funtions/ezyfit/ezyfit % fit data to a curve
addpath /home1/datahome/co_arg/larduini/Andrea/Life_expectancy/aux_functions


% INPUT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% list from JCOMMOPS with fields name = REF, STATUS, COUNTRY, DEPLOYMENT DATE, MODEL
list_dir = '/home1/datahome/co_arg/larduini/Lists/All_EA_floats.csv'
dac_dir = '/home/ref-argo/gdac/'
config_param = {'CONFIG_CycleTime_hours'}
% only consider sample size superior to 10floats. The survival rate from a smaller sample would be less reliable.
sample_size_limit = 10 % floats
output_folder = '/home1/datahome/co_arg/larduini/Exports/Survival_rates/Sample_EA_etape4'
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%% get floats from list
[Floats_list] = read_csv(list_dir,',');

% number of floats
Floats_list.WMO = cellstr(Floats_list.REF);

% when there is a not valid WMO in list
index_wmo = cellfun(@(x) length(x)~=7, Floats_list.WMO);
Floats_list_field = fieldnames(Floats_list);
for ifield = 1: length(Floats_list_field)
    Floats_list.(Floats_list_field{ifield})(index_wmo,:) = [];
end

% look for dac path
% get dac
[Floats_paths] = get_floats_filespath(dac_dir, Floats_list.WMO);
% n_floats = length(Floats_list.WMO.data);
index_dac = ~ismember(cellstr(Floats_list.REF), Floats_paths.WMO);
for inames = 1 : length(Floats_list_field)
    Floats_list.(Floats_list_field{inames})(index_dac,:) = [];
end


% sort by wmo before merge structs
[Floats_list.WMO, index_sort] = sort(Floats_list.WMO);
for inames = 1 : length(Floats_list_field)
    Floats_list.(Floats_list_field{inames}) = Floats_list.(Floats_list_field{inames})(index_sort,:);
end
[Floats_paths.WMO, index_sort] = sort(Floats_paths.WMO);
Floats_list.DAC = Floats_paths.DAC(index_sort)';

Floats_list.WMO = char(Floats_paths.WMO); 


%% get data from gdac
disp(' ')
disp('Getting data from gdac...')


% if CycleTime param
if contains(config_param,'CycleTime')
    calcul_param = config_param;
    config_param = {'CONFIG_CycleTime_days', 'CONFIG_CycleTime_hours', 'CONFIG_CycleTime_minutes'};
    where_file = {'config','config','config'};
elseif contains(config_param,'CTDPoints')
    % use also CONFIG_CycleTime_days
    calcul_param = config_param;
    config_param = {'CONFIG_CycleTime_hours', 'CONFIG_CycleTime_days', 'CONFIG_CycleTime_minutes'...
                    'CONFIG_ParkSamplingPeriod_hours', 'CONFIG_ProfilePressure_dbar',...
                    'CONFIG_PressureThresholdDataReductionShallowToIntermediate_dbar',...
                    'CONFIG_PressureThresholdDataReductionIntermediateToDeep_dbar',...
                    'CONFIG_ProfileSurfaceSlicesThickness_dbar',...
                    'CONFIG_ProfileIntermediateSlicesThickness_dbar',...
                    'CONFIG_ProfileBottomSlicesThickness_dbar'};
    where_file = {'config','config','config','config','config','config',...
                  'config','config','config', 'config'};
else
    calcul_param = config_param;
    where_file = {'config'};
end

% date from traj file
all_params = [config_param {'JULD'}];
where_file = [where_file {'traj'}];
mc_code = {'all'};

[Floats] = get_floats_data_gdac_v3_FINAL(Floats_list, all_params, where_file, dac_dir, mc_code);


%% calculations
disp(' ')
disp('Calculations...')

if contains(calcul_param,'CycleTime')
    [Floats] = calculate_CyclePeriod(Floats,'hours');

elseif contains(calcul_param,'CTDPoints')
    [Floats] = calculate_CyclePeriod(Floats,'days');
    config_param(contains(config_param,'CONFIG_CycleTime_days')) = [];
    [Floats] = calculate_CTDPoints(Floats,config_param,0);
    
end


%% get vertical km and float age

% vertical km
[Analysis.vertical_km, Analysis.vertical_km_mean] = get_vertical_km_multiprof(Floats, dac_dir);


% float age
index = cellfun(@(x) isempty(x), Floats.JULD.data);
Floats.JULD.data(index) = {NaN};

Analysis.float_age = cellfun(@(x) max(x) - min(x), Floats.JULD.data)/365;

Floats = rmfield(Floats,'JULD');
Floats = rmfield(Floats,'REFERENCE_DATE_TIME');


%% make format
disp(' ')
disp('Formatting...')

remove_cycles = [0,1];
[Floats, notused_floats] = format_data_for_plotting(Floats, remove_cycles);


n_floats = length(Floats.WMO.data);
n_cycles = cellfun(@(x) length(x), Floats.(calcul_param{1}).data);

% same floats for country, model and date
index_data = ismember(cellstr(Floats_list.WMO), notused_floats.WMO);
for inames = 1 : length(Floats_list_field)
    Floats_list.(Floats_list_field{inames})(index_data,:) = [];
end
Analysis.vertical_km(index_data) = [];
Analysis.vertical_km_mean(index_data) = [];
Analysis.float_age(index_data) = [];



n_floats = length(Floats.(calcul_param{1}).data);


%% get survival rate

% first config value and number of cycles
Analysis.first_configvalue = cellfun(@(x) x(1), Floats.(calcul_param{1}).data);
Analysis.last_cycle = cellfun(@(x) x(end), Floats.(calcul_param{1}).cycle);

% config changed or not
Analysis.CONFIG_changed = NaN(n_floats,1);
for ifloat = 1: n_floats
    Analysis.CONFIG_changed(ifloat) = length(unique(Floats.(calcul_param{1}).data{ifloat}));
end
n_not_changed = sum(Analysis.CONFIG_changed == 1);

% use not changing floats
notchan_configvalue = Analysis.first_configvalue(Analysis.CONFIG_changed == 1);
notchan_last_cycle = Analysis.last_cycle(Analysis.CONFIG_changed == 1);
notchan_verticalkm = Analysis.vertical_km(Analysis.CONFIG_changed == 1);
notchan_float_age = Analysis.float_age(Analysis.CONFIG_changed == 1);
notchan_WMO = Floats_list.WMO(Analysis.CONFIG_changed == 1,:);
notchan_MODEL = Floats_list.MODEL(Analysis.CONFIG_changed == 1,:);
notchan_status = Floats_list.STATUS(Analysis.CONFIG_changed == 1,:);



% get all different config values
unique_values = unique(notchan_configvalue);
unique_values(isnan(unique_values)) = [];
% get biggest cycles number
max_cycle = max(notchan_last_cycle);
max_verticalkm = max(notchan_verticalkm);
max_float_age = max(notchan_float_age);
 
plot_label = cell(1,length(unique_values));
sample_size = NaN(1,length(unique_values));

%% Test Luca %%
disp('computing...')
close all

%%% Chose the value of the config param wanted to compare survival rate %%%
index_values = {};
cycles_vector = {};
verticalkm_vector = {};
floatage_vector = {};
floatage_vector2 = {};
max_float_age2 = {};
WMO_vector = {};
MODEL_vector = {};
status_vector = {};
sample_size = {};
plot_label = {};
death_floats = {};
alive_index = {};
MODEL_vector2 = {};
max_cycle={};
vect_cycle = {};
alive_idx = {};
sample_s_test = {};
floats_survived = {};
plot_data_cycle = {};
plot_data_table_cycle= {};
cycle_numbers= {};
table_cycle_numbers= {};
vect_vkm={};
alive_idx_vkm = {};
sample_s_vkm={};
plot_data_vkm={};
max_verticalkm= {};
plot_data_table_vkm= {};
vkm_traveled= {};
table_vkm= {};
floatage_intervals = {};
vect_age= {};
alive_idx_age= {};
sample_s_age= {};
plot_data_age= {};
plot_data_table_age= {};
age_reached= {};
table_age= {};

for ivalue= 1:length(unique_values)
    index_values{ivalue} = [notchan_configvalue == unique_values(ivalue)];
    cycles_vector{ivalue} = notchan_last_cycle(index_values{ivalue});
    verticalkm_vector{ivalue} = notchan_verticalkm(index_values{ivalue});
    floatage_vector{ivalue} = notchan_float_age(index_values{ivalue});
    
    max_cycle{ivalue} = max(cycles_vector{ivalue});
    max_verticalkm{ivalue}= max(verticalkm_vector{ivalue});
    %Mise en place d'un âge limite au-delà duquel on considère les valeurs d'âge erronnée (ici 10ans max)
    floatage_vector2{ivalue} = floatage_vector{ivalue};    
    for ii = 1:length(floatage_vector2{ivalue})
        if floatage_vector2{ivalue}(ii)>= 10;
            floatage_vector2{ivalue}(ii) = NaN;
        end
    end
    max_float_age2{ivalue} = max(floatage_vector2{ivalue});

    WMO_vector{ivalue} = notchan_WMO(index_values{ivalue},:);   
    MODEL_vector{ivalue} = notchan_MODEL(index_values{ivalue},:);
    status_vector{ivalue} = notchan_status(index_values{ivalue},:);
 
    sample_size{ivalue} = sum(index_values{ivalue});
    plot_label{ivalue} = {['CONFIG = ' num2str(unique_values(ivalue)) ' (' num2str(sample_size{ivalue}) ' floats)']};

    death_floats{ivalue} = sum(contains(cellstr(status_vector{ivalue}), 'INACTIVE')) + sum(contains(cellstr(status_vector{ivalue}), 'CLOSED'));
    alive_index{ivalue} = ~(contains(cellstr(status_vector{ivalue}), 'INACTIVE') | contains(cellstr(status_vector{ivalue}), 'CLOSED'));
    
%%% Create a table indexing which float is alive or dead according to the model
    MODEL_vector2{ivalue} = cellstr(MODEL_vector{ivalue});
    unique_model{ivalue} = unique(MODEL_vector2{ivalue});
    unique_model_nb{ivalue}= length(unique_model{ivalue});

    for imodel = 1:unique_model_nb{ivalue}
        model_idx{ivalue}{imodel} = (contains(cellstr(MODEL_vector2{ivalue}), unique_model{ivalue}(imodel)));
        str_model{ivalue}(imodel) = [string(unique_model{ivalue}(imodel))];
        table_model_idx{ivalue} = table(model_idx{ivalue}{:});
    end

    cell_string{ivalue} = cellstr(str_model{ivalue});
    for imodel = 1:unique_model_nb{ivalue}
        table_model_idx{ivalue}.Properties.VariableNames{imodel} = cell_string{ivalue}{imodel};
    end




    %%% Loop on cycles
    for imodel = 1:unique_model_nb{ivalue}
        for icycle = 1:max_cycle{ivalue}
            vect_cycle{ivalue}{imodel}= cycles_vector{ivalue}(table_model_idx{ivalue}{:,imodel});
            alive_idx_cycle{ivalue}{imodel} = alive_index{ivalue}(table_model_idx{ivalue}{:,imodel});
            sample_s_cycle{ivalue}{icycle,imodel} =  sum(vect_cycle{ivalue}{imodel}(~alive_idx_cycle{ivalue}{imodel}) <= icycle) + sum(vect_cycle{ivalue}{imodel} >= icycle);
            floats_survived_cycle{ivalue}{icycle,imodel} = sum(vect_cycle{ivalue}{imodel} >= icycle);
            plot_data_cycle{ivalue}{icycle,imodel} = sum(vect_cycle{ivalue}{imodel} >= icycle)/sample_s_cycle{ivalue}{icycle,imodel}*100;
        end
    end



    plot_data_table_cycle{ivalue} = cell2table(plot_data_cycle{ivalue}, 'VariableNames', cell_string{ivalue});
    cycle_numbers{ivalue} = (1:max_cycle{ivalue})';
    table_cycle_numbers{ivalue} = table(cycle_numbers{ivalue}, 'VariableNames',{'Cycle_Number'});
    %%% Final table for cycles below:
    plot_data_table_cycle{ivalue} = [table_cycle_numbers{ivalue},plot_data_table_cycle{ivalue}]


    %%% loop vertical km
    % vkm_intervals = 0:10:max_verticalkm; %%%% Possibility to create some verticalkm intervals to simplify lisibility (every 10 Kms or something like that.
    for imodel = 1:unique_model_nb{ivalue}
        for ivkm = 1:max_verticalkm{ivalue}
            vect_vkm{ivalue}{imodel} = verticalkm_vector{ivalue}(table_model_idx{ivalue}{:,imodel});
            alive_idx_vkm{ivalue}{imodel} = alive_index{ivalue}(table_model_idx{ivalue}{:,imodel});
            sample_s_vkm{ivalue}{ivkm,imodel} =  sum(vect_vkm{ivalue}{imodel}(~alive_idx_vkm{ivalue}{imodel}) <= ivkm) + sum(vect_vkm{ivalue}{imodel} >= ivkm);
            plot_data_vkm{ivalue}{ivkm,imodel} = sum(vect_vkm{ivalue}{imodel} > ivkm)/sample_s_vkm{ivalue}{ivkm,imodel}*100;
        end
    end

    plot_data_table_vkm{ivalue} = cell2table(plot_data_vkm{ivalue}, 'VariableNames', cell_string{ivalue});
    vkm_traveled{ivalue} = (1:max_verticalkm{ivalue})';
    table_vkm{ivalue} = table(vkm_traveled{ivalue}, 'VariableNames', {'Vertical_km_traveled'});
    %%% Final table for vertical distance below:
    plot_data_vkm{ivalue} = [table_vkm{ivalue},plot_data_table_vkm{ivalue}]


    %%% loop float age
    floatage_intervals{ivalue} = 0:0.1:max_float_age2{ivalue};
    for imodel = 1:unique_model_nb{ivalue}
        for iage = 1:length(floatage_intervals{ivalue})
            vect_age{ivalue}{imodel} = floatage_vector{ivalue}(table_model_idx{ivalue}{:,imodel});
            alive_idx_age{ivalue}{imodel} = alive_index{ivalue}(table_model_idx{ivalue}{:,imodel});
            sample_s_age{ivalue}{iage,imodel} =  sum(vect_age{ivalue}{imodel}(~alive_idx_age{ivalue}{imodel}) <= floatage_intervals{ivalue}(iage)) + ... 
            sum(vect_age{ivalue}{imodel} >= floatage_intervals{ivalue}(iage));
            plot_data_age{ivalue}{iage,imodel} = sum(vect_age{ivalue}{imodel} > floatage_intervals{ivalue}(iage))/sample_s_age{ivalue}{iage,imodel}*100;
        end
    end

    plot_data_table_age{ivalue} = cell2table(plot_data_age{ivalue}, 'VariableNames', cell_string{ivalue});
    age_reached{ivalue} = (floatage_intervals{ivalue})';
    table_age{ivalue} = table(age_reached{ivalue}, 'VariableNames', {'Age_reached'});
    %%% Final table for age below:
    plot_data_age{ivalue} = [table_age{ivalue},plot_data_table_age{ivalue}]



    %%% Plot
%     clear title
    lgd_str={};
    super_title=[];
%     title_str= {};

    figure(ivalue)
%     set(gcf, 'Position', get(0, 'Screensize'));
    total_floats = size(WMO_vector{ivalue},1);
    super_title= [cellstr(calcul_param) + " = " + unique_values(ivalue) + " [" + total_floats + " floats total]"];
    annotation('textbox', [0.5, 1, 0, 0], 'string', super_title, 'HorizontalAlignment', 'center', 'Fontsize', 18, 'FitBoxToText', 'on', 'Interpreter', 'none')
    
    subplot(2,2,1)
    %Survival rates per cycles
    plot_data_table_cycle2 = plot_data_table_cycle;
    plot_data_table_cycle2{5}.PROVOR_II = [];
    plot_data_table_cycle2{5}.PROVOR_III = [];
    plot_data_table_cycle2{10}.PROVOR_II = [];
% %     
    unique_model_nb2 = unique_model_nb
    unique_model_nb2{5} = unique_model_nb{5} -2
    unique_model_nb2{10} = unique_model_nb{10} -1
    
    for imodel = 1:unique_model_nb2{ivalue}
        plot(plot_data_table_cycle2{ivalue}{:,imodel+1}, 'LineWidth', 2)
        lgd_str{imodel} = cell_string{ivalue}{imodel} + " (" + sum(table_model_idx{ivalue}{:,imodel}) + " floats)";
        hold on
    end
    ylim([0 100])
    xlabel('Number of cycles reached')
    ylabel('Survival rate (%)')
    legend(lgd_str{:})
    title('Survival rate per cycle per float type')
    
    subplot(2,2,2)
    %Survival rates per age
    plot_data_age2 = plot_data_age;
    plot_data_age2{5}.PROVOR_II = [];
    plot_data_age2{5}.PROVOR_III = [];
    plot_data_age2{10}.PROVOR_II = [];
    
    for imodel=1:unique_model_nb2{ivalue}
        plot(plot_data_age2{ivalue}{:,1}, plot_data_age{ivalue}{:,imodel+1}, 'LineWidth', 2)
        lgd_str{imodel} = cell_string{ivalue}{imodel} + " (" + sum(table_model_idx{ivalue}{:,imodel}) + " floats)";
        hold on
    end
    xlim([0 max_float_age2{ivalue}])
    ylim([0 100])
    xlabel('Age reached (year)')
    ylabel('Survival rate (%)')
    legend(lgd_str{:})
    title('Survival rate per age reached per float type')
    
    subplot(2,2,3:4)
    %Survival rate per vertical distance traveled
    plot_data_vkm2 = plot_data_vkm;
    plot_data_vkm2{5}.PROVOR_II = [];
    plot_data_vkm2{5}.PROVOR_III = [];
    plot_data_vkm2{10}.PROVOR_II = [];
%     
    for imodel=1:unique_model_nb2{ivalue}
        plot(plot_data_vkm2{ivalue}{:,imodel+1}, 'LineWidth', 2)
        lgd_str{imodel} = cell_string{ivalue}{imodel} + " (" + sum(table_model_idx{ivalue}{:,imodel}) + " floats)";
        hold on
    end
    ylim([0 100])
    xlabel('Vertical distance traveled (Km)')
    ylabel('Survival rate (%)')
    legend(lgd_str{:})
    title('Survival rate per vertical Kms traveled per float type')
    
    
end


