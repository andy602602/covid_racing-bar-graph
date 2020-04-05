%% Load data
% full_data = readtable('E:\GoogleDrive\corona\full_data.csv');
full_data = webread('https://covid.ourworldindata.org/data/ecdc/full_data.csv');
max_date = max(full_data.date);
min_date = min(full_data.date);
country = unique(full_data.location);
rs_data = zeros(days(max_date - min_date)+1,4,length(country));
%% Refill data, because some dates not continue
refill_data = array2table([min_date:max_date]','VariableNames',{'date'});
for k = 1:length(country)
    tmp_data = full_data;
    data_filt = (tmp_data.location~=string(country{k})).* [1:size(tmp_data,1)]';
    data_filt(data_filt==0)='';
    tmp_data(data_filt,:)=[];
    sort_data = ismember(refill_data(:,1), tmp_data(:,1)).* [1:size(refill_data,1)]';
    sort_data(sort_data==0)='';
    rs_data(sort_data,:,k) = table2array(tmp_data(:,3:6));
end
%% Fill the date which didn't record 
for k = 1:length(country)
    for i = 1:size(rs_data)-1
        window = rs_data(i:i+1,3:4,k);
        if norm(window(1,:))~=0 && norm(window(2,:))==0
            window(2,:) = window(1,:);
        end
        rs_data(i:i+1,3:4,k) = window;
    end
end
%% Interpolation the data
rs_data(:,:,42) = 0;  %except China
ds = 0.05;
covid_date = [1:size(rs_data,1)];
covid_date_interp = [1:ds:size(rs_data,1)];
rs_data_interp = interp1(covid_date',rs_data(:,3:4,:),covid_date_interp,'linear');
%% Transfer the id of countries to sort number
rank_tmp = zeros([size(rs_data_interp,3),size(rs_data_interp,1)]);
cases_tmp = zeros([size(rs_data_interp,3),size(rs_data_interp,1)]);
top_num = 21; % one of it is World
for j = 1:size(rs_data_interp,1)
    [M,I] = maxk(round(rs_data_interp(j,1,:)),top_num);
    findzero = find(M==0);
    if ~isempty(findzero)
        I(findzero) = '';
    end
    I(I==42)='';  %except China
    rank_tmp(squeeze(I),j) = 1:length(I);
    cases_tmp(squeeze(I),j) = squeeze(rs_data_interp(j,1,I));
end
%% Smooth the bar changing anime
tmp = zeros(1,size(rs_data_interp,3));
rank_smooth = zeros(size(rs_data_interp,3),size(rs_data_interp,1));
for k = 1:size(rs_data_interp,3)
    tmp = rank_tmp(k,:); 
    tmp(tmp~=0) = smooth(tmp(tmp~=0));  %smooth is toolbox tool
    rank_smooth(k,:) = tmp;
end
%% Plot racing barrr
handle_figure = figure(1);
handle_figure.Position = [63,1,1304,690];
handle_axes = gca;
covidax = axes;

%=====bar colors, make colors messy=====%
h = linspace(0,240,size(rs_data_interp,3))/360;
s = repmat(1,1,size(rs_data_interp,3));
v = repmat(1,1,size(rs_data_interp,3));
country_colormap_full = squeeze(hsv2rgb(h,s,v));
% country_colormap_full = country_colormap_full(randsample(size(rs_data_interp,3)*5,size(rs_data_interp,3)),:,:);
country_colormap_full = country_colormap_full(randperm(size(rs_data_interp,3)),:,:);

country_ticks = cell2table(country);
xmax = ceil(log10(max(rs_data_interp(:))))+1;
date_string = cellstr( datestr(min_date:max_date,'mmm - dd'));

%=====image processing=====%
covid19_img = imread('covid19.png');
covid19_img_mask = imfill(imbinarize(sum(covid19_img,3),graythresh(sum(covid19_img,3))),'holes');
se = strel('square',15);
covid19_img_mask = imgaussfilt(double(imerode(covid19_img_mask,se)),9);

st_date = 61;  %started from 03/01
for j = st_date*(1/ds)+1:size(rs_data_interp,1)
    
    [M,~] = maxk(round(rs_data_interp(j,1,:)),top_num);
    
    country_lable = country_ticks.country; 
    rank = rank_smooth(:,j);    
    cases = cases_tmp(:,j);   
    country_colormap = country_colormap_full;
    zero_elements = rank==0;
    
    country_lable(zero_elements)=''; 
    rank(zero_elements)='';    
    cases(zero_elements)='';
    country_colormap(zero_elements,:) = '';
    
    %Because there's a error when the bar had two or more same rank
    [B,Isort] = sort(rank);
    if length(unique(B)) < length(B)  
        continue;
    end
    
%=====plot barchart=====%
    for kk=1:length(rank)-1
        tmp = barh(handle_axes,rank(kk,:),cases(kk,:), 'FaceColor', country_colormap(kk,:),'LineStyle', 'none');
        text(handle_axes,cases(kk,:), rank(kk,:), "  "+num2str(addComma(int32(cases(kk,:))),'%d'), 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left','FontSize',11,'FontName', 'Times New Roman');
        hold(handle_axes,'on');
    end
    hold(handle_axes,'off');
    
    set(handle_axes,'FontSize',12,'FontName', 'Times New Roman', 'Position', [0.13,0.09,0.8,0.8], 'XGrid', 'on', 'XAxisLocation', 'top', 'LineWidth', 1.5, 'GridAlpha',0.5)
    axis(handle_axes,[0 (max(M(2:end)))*1.2 1 top_num+1],'ij','normal')
    text(handle_axes,max(M(2:end))*0.83, top_num*0.9,  "Total cases : "+num2str(addComma(int32(max(M))),'%d'),'Color','red', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left','FontSize',25,'FontName', 'Times New Roman');
    text(handle_axes,max(M(2:end))*0.89, top_num*0.8,[' ' + string(date_string(floor(j*ds)+1))],'Color','magenta', 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left','FontSize',30,'FontName', 'Times New Roman','FontWeight','bold')
    box(handle_axes,'off')
    yticks(handle_axes,[B(2:end)])
    yticklabels(handle_axes,country_lable(Isort(2:end)))

%=====dynamic x-axis control=====%
    xlablim = round((max(M(2:end)))*1.2);
    xdig = numel(num2str(xlablim))-1;
    xlablim = round((max(M(2:end)))*1.2,-xdig)+10^xdig;
    xlablim = [0:round(xlablim/4,-xdig):xlablim];
    xticks(handle_axes,xlablim)
    xticklabels(handle_axes,AddCommaArr(xlablim))
    
    title(handle_axes,['CORONAVIRUS (COVID-19)'],'FontSize',25,'Color',[1,0.5,0])
    set(gcf,'color','w')
    
    set(covidax,'Position' , [0.66,0.35,0.25,0.25])
    c = imagesc(covidax,imrotate(covid19_img,j*0.25));  %imrotate is toolbox tool
    axis(covidax,'image','off')
    set(c,'AlphaData',imrotate(covid19_img_mask,j*0.25))

%=====if record video=====%
    frame(j) = getframe(gcf);
    pause(0.01)
end
%% Record as video
%=====clear the empty frames=====%
frame_tmp = reshape(struct2cell(frame),2,[])';
frame_tmp = frame_tmp(~cellfun(@isempty,frame_tmp(:,1)),:);
frame_tmp = cell2struct(frame_tmp,{'cdata','colormap'},2);
%=====clear the empty frames=====%
v = VideoWriter('covid-19_top_04043.mp4');
v.FrameRate = 20;
v.Quality = 100;
open(v)
writeVideo(v,frame_tmp);
close(v);
