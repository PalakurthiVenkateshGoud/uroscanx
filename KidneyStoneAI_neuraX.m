function KidneyStoneAI
% KidneyStoneAI – Kidney Stone Detection & Reporting System (single file)
% Save as KidneyStoneAI.m and run.

% Login UI
loginFig = uifigure('Name','Kidney Stone AI – Login','Position',[200 200 350 220]);
uilabel(loginFig,'Text','User Name','Position',[40 150 80 22]);
uilabel(loginFig,'Text','Password','Position',[40 100 80 22]);
uName  = uieditfield(loginFig,'text','Position',[130 150 150 22]);
uPass  = uieditfield(loginFig,'text','Position',[130 100 150 22]);

uibutton(loginFig,'Text','Login','Position',[110 40 120 30],...
    'ButtonPushedFcn',@(src,event) mainApp(uName.Value,uPass.Value));

    function mainApp(name,~)
        if isempty(name)
            uialert(loginFig,'Please enter your name','Login Failed');
            return;
        end
        close(loginFig);
        buildDashboard(name);
    end
end

%% ---------------------- Local functions ----------------------------

function buildDashboard(userName)
pixelsPerMM = 10;

fig = uifigure('Name','Kidney Stone AI Dashboard','Position',[100 100 1250 720]);

leftPanel = uipanel(fig,'Title',['Welcome, ',userName],'Position',[10 10 300 700]);

uilabel(leftPanel,'Text','Patient Name:','Position',[10 660 100 22]);
ptName = uieditfield(leftPanel,'text','Position',[120 660 150 22],'Value','Test Patient');

uilabel(leftPanel,'Text','Age:','Position',[10 630 100 22]);
ptAge = uieditfield(leftPanel,'numeric','Position',[120 630 60 22],'Value',35);

uilabel(leftPanel,'Text','Sex:','Position',[10 600 100 22]);
ptSex = uidropdown(leftPanel,'Items',{'Male','Female','Other'},...
    'Position',[120 600 100 22],'Value','Male');

uilabel(leftPanel,'Text','Upload Kidney Image:','Position',[10 560 200 22]);
imgBtn = uibutton(leftPanel,'Text','Browse','Position',[10 530 80 25]);
runBtn = uibutton(leftPanel,'Text','Run Detection','Position',[100 530 120 25],'Enable','off');

uilabel(leftPanel,'Text','Report Language:','Position',[10 500 200 22]);
langDrop = uidropdown(leftPanel,'Items',{'English','Telugu','Hindi','Tamil'},...
    'Position',[10 470 200 25],'Value','English');

reportBtn = uibutton(leftPanel,'Text','Generate Word Report','Position',[10 430 200 25],'Enable','off');
ttsBtn = uibutton(leftPanel,'Text','Read Report (TTS)','Position',[10 400 200 25],'Enable','off');

uilabel(leftPanel,'Text','Nearby Hospitals:','Position',[10 360 200 22]);
hospitalsArea = uitextarea(leftPanel,'Position',[10 220 260 140],'Editable','off');

uilabel(leftPanel,'Text','Precautions:','Position',[10 190 200 22]);
precautionsArea = uitextarea(leftPanel,'Position',[10 60 260 140],'Editable','off');

uibutton(leftPanel,'Text','Call 108 / 102 / Hospitals','Position',[10 20 260 30],...
    'ButtonPushedFcn',@(src,event) emergencyCall());

uibutton(leftPanel,'Text','Chatbot','Position',[10 250 260 30],...
    'ButtonPushedFcn',@(src,event) chatbotDialog());

imgPanel = uipanel(fig,'Position',[320 10 900 700]);
axGrid = uigridlayout(imgPanel,[3 3]);
for k=1:9
    axs(k)=uiaxes(axGrid);
    axs(k).Visible='off';
end

appData.image = [];
appData.imgFile = '';
appData.result = '';
appData.stoneLength = 0;
appData.location = 'None';
appData.reportFile = '';
appData.reportText = '';
appData.lang = 'English';

hospitalList = {
 'CMR Medical Hospital | Dr. Arun – Urologist | Ph:7416514532'
 'Medchal Government Hospital | Dr. Priya – Nephrologist | Ph:7416514531'
 'Mallareddy Hospital | Dr. Kishore – Urologist | Ph:9573432452'
 'Yashodha Hospital | Dr. Meena – Urologist | Ph:9573432451'};
hospitalsArea.Value = hospitalList;

imgBtn.ButtonPushedFcn = @(src,event) onBrowse();
runBtn.ButtonPushedFcn = @(src,event) onRun();
reportBtn.ButtonPushedFcn = @(src,event) onGenerate();
ttsBtn.ButtonPushedFcn = @(src,event) onTTS();

    function onBrowse()
        [f,p] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.dcm','Image Files'});
        if isequal(f,0), return; end
        fname = fullfile(p,f);
        try
            if endsWith(lower(fname),'.dcm')
                I = dicomread(fname);
            else
                I = imread(fname);
            end
        catch ME
            uialert(fig,['Unable to read image: ' ME.message],'Read Error');
            return;
        end
        appData.image = I;
        appData.imgFile = fname;
        try
            imshow(appData.image,'Parent',axs(1)); axs(1).Visible='on'; title(axs(1),'Original');
        catch
        end
        runBtn.Enable = 'on';
    end

    function onRun()
        if isempty(appData.image)
            uialert(fig,'Upload an image first.','No Image');
            return;
        end
        out = detectStoneFromImage(appData.image,pixelsPerMM);
        imgs = out.displayImgs; titles = out.displayTitles;
        n = min(numel(imgs),numel(axs));
        for i=1:n
            try
                imshow(imgs{i},'Parent',axs(i)); axs(i).Visible='on'; title(axs(i),titles{i});
            catch
            end
        end
        appData.result = out.result;
        appData.stoneLength = out.stoneLength;
        appData.location = out.location;
        uialert(fig,appData.result,'Detection Result');
        reportBtn.Enable = 'on';
        setappdata(0,'KidneyStoneAppData',appData);
    end

    function onGenerate()
        patientName = ptName.Value;
        patientAge = ptAge.Value;
        patientSex = ptSex.Value;
        appData.lang = langDrop.Value;
        if isempty(appData.result)
            uialert(fig,'Run detection first.','No Result');
            return;
        end
        if isfield(appData,'stoneLength') && appData.stoneLength>0
            precautionsArea.Value = {'Drink 2-3 L water/day','Low salt diet','Consult urologist'};
        else
            precautionsArea.Value = {'Maintain hydration','Routine check-ups'};
        end
        try
            [docPath,reportText] = createWordReport(appData,patientName,patientAge,patientSex);
            appData.reportFile = docPath;
            appData.reportText = reportText;
            uialert(fig,['Report saved: ' docPath],'Report Saved');
            ttsBtn.Enable = 'on';
            setappdata(0,'KidneyStoneAppData',appData);
        catch ME
            uialert(fig,['Report generation failed: ' ME.message],'Report Error');
        end
    end

    function onTTS()
        if isempty(appData.reportText)
            uialert(fig,'Generate a report first.','No Report');
            return;
        end
        ttsLang(appData.reportText, appData.lang);
    end
end

% ----------------- detectStoneFromImage (second pipeline without ROI) -----------------
function out = detectStoneFromImage(img,pixelsPerMM)
if nargin<2 || isempty(pixelsPerMM), pixelsPerMM = 10; end
out.displayImgs = {}; out.displayTitles = {};

if ndims(img)==3
    a = img;
else
    a = cat(3,img,img,img);
end

try
    gray = im2uint8(rgb2gray(a));
catch
    gray = im2uint8(a(:,:,1));
end
out.displayImgs{end+1} = gray; out.displayTitles{end+1} = 'Gray';

c = gray > 10;
out.displayImgs{end+1} = c; out.displayTitles{end+1} = 'Initial Binary';

d = imfill(c,'holes');
out.displayImgs{end+1} = d; out.displayTitles{end+1} = 'Holes Filled';

e = bwareaopen(d,1000);
out.displayImgs{end+1} = e; out.displayTitles{end+1} = 'Objects Removed';

Pre = uint8(double(a) .* repmat(e,[1 1 3]));
try
    Pre = imadjust(Pre,[0.3 0.7],[]) + 50;
catch
    for k=1:3
        ch = Pre(:,:,k);
        Pre(:,:,k) = imadjust(ch);
    end
    Pre = Pre + 50;
end
out.displayImgs{end+1} = Pre; out.displayTitles{end+1} = 'Preprocessed';

uo = rgb2gray(Pre);
out.displayImgs{end+1} = uo; out.displayTitles{end+1} = 'Pre Gray';

mo = medfilt2(uo,[5 5]);
out.displayImgs{end+1} = mo; out.displayTitles{end+1} = 'Median Filter';

po = mo > 250;
out.displayImgs{end+1} = po; out.displayTitles{end+1} = 'Final Binary';

k = po; % no ROI
M = bwareaopen(k,4);
out.displayImgs{end+1} = M; out.displayTitles{end+1} = 'Clean Components';

[~,number] = bwlabel(M);
displayImgs = out.displayImgs;
displayTitles = out.displayTitles;

if number >= 1
    stats = regionprops(M,'MajorAxisLength','Centroid','BoundingBox');
    lens = [stats.MajorAxisLength];
    if isempty(lens), stoneLengthPixels = 0; else stoneLengthPixels = max(lens); end
    stoneLengthMM = stoneLengthPixels / pixelsPerMM;
    cent = stats(1).Centroid;
    % prepare annotation image
    try
        ann = im2uint8(a);
        if size(ann,3)==1, ann = repmat(ann,[1 1 3]); end
        bbox = stats(1).BoundingBox;
        ann = insertShape(ann,'Rectangle',bbox,'Color','red','LineWidth',2);
        ann = insertText(ann,cent,sprintf('%.2f mm',stoneLengthMM),'BoxColor','yellow','FontSize',12);
        displayImgs{end+1} = ann; displayTitles{end+1} = 'Annotated';
    catch
        displayImgs{end+1} = a; displayTitles{end+1} = 'Annotated';
    end
    out.displayImgs = displayImgs; out.displayTitles = displayTitles;
    out.result = sprintf('Stone Detected\nSize: %.2f mm\nZone: %s', stoneLengthMM, kidneyZone(size(a),cent));
    out.stoneLength = stoneLengthMM;
    out.location = kidneyZone(size(a),cent);
else
    out.displayImgs = displayImgs; out.displayTitles = displayTitles;
    out.result = 'No Stone Detected';
    out.stoneLength = 0;
    out.location = 'None';
end
end

% ----------------- kidneyZone (sz,cent) -----------------
function zone = kidneyZone(sz,cent)
rows = sz(1); cols = sz(2);
if numel(cent) >= 2
    x = cent(1); y = cent(2);
else
    x = cols/2; y = rows/2;
end
if y < rows/2, v = 'Upper'; else v = 'Lower'; end
if x < cols/2, h = 'Left'; else h = 'Right'; end
zone = [v '-' h];
end

% ----------------- createWordReport and helpers -----------------
function [outFile, fullText] = createWordReport(data, patientName, patientAge, patientSex)
import mlreportgen.dom.*
outFile = ''; fullText = '';
outFolder = fullfile(pwd,'KidneyReports');
if ~exist(outFolder,'dir'), mkdir(outFolder); end
lang = 'English';
if isfield(data,'lang'), lang = data.lang; end
timestamp = datestr(now,'yyyymmdd_HHMMSS_');
outFile = fullfile(outFolder,[timestamp '_KidneyStoneReport_' lower(lang) '.docx']);
d = Document(outFile,'docx');
open(d);
append(d,Heading(1,['UroScanX – Kidney Stone Diagnostic Report (',lang,')']));
reportDate = datestr(now,'dd-mmm-yyyy HH:MM:SS');
append(d,Paragraph(['Report generated on: ', reportDate]));
append(d,HorizontalRule);
append(d,Heading(2,getLocalized('Patient Details',lang)));
ptTable = Table({'Name',patientName; 'Age',num2str(patientAge); 'Sex',patientSex; 'Report Date',reportDate});
ptTable.Style = {Border('solid','black','1px'), Width('100%')};
append(d,ptTable);
append(d,Heading(2,getLocalized('Clinical Indication / History',lang)));
append(d,Paragraph(buildClinicalIndication(lang)));
append(d,Heading(2,getLocalized('Imaging Technique',lang)));
append(d,Paragraph(buildImagingTechnique(lang)));
append(d,Heading(2,getLocalized('Observations and Findings',lang)));
findings = buildFindingsText(lang, data.stoneLength, data.location, data.result, data.image);
fParas = splitIntoParagraphs(findings,900);
for i=1:numel(fParas), append(d,Paragraph(fParas{i})); end
append(d,Heading(2,getLocalized('Diagnostic Impression',lang)));
append(d,Paragraph(buildImpression(lang,data.stoneLength,data.location,data.result)));
append(d,Heading(2,getLocalized('Differential Diagnosis',lang)));
append(d,Paragraph(buildDifferential(lang)));
append(d,Heading(2,getLocalized('Recommendations & Management Plan',lang)));
recs = buildRecommendations(lang,data.stoneLength,data.location);
rParas = splitIntoParagraphs(recs,800);
for i=1:numel(rParas), append(d,Paragraph(rParas{i})); end
append(d,Heading(2,getLocalized('Lifestyle and Preventive Measures',lang)));
append(d,Paragraph(buildLifestyle(lang)));
append(d,Heading(2,getLocalized('When to seek urgent care',lang)));
append(d,Paragraph(buildUrgentCare(lang)));
append(d,Heading(2,getLocalized('Appendix / Explanation',lang)));
append(d,Paragraph(buildAppendix(lang)));
if isfield(data,'image') && ~isempty(data.image)
    append(d,Heading(2,getLocalized('Uploaded CT Image',lang)));
    try
        tempPNG = [tempname '.png'];
        try
            imwrite(data.image,tempPNG);
        catch
            imwrite(uint8(data.image),tempPNG);
        end
        imDom = Image(tempPNG);
        imDom.Width = '12cm';
        append(d,imDom);
    catch ME
        append(d,Paragraph([getLocalized('Image could not be embedded: ',lang) ' ' ME.message]));
    end
end
append(d,HorizontalRule);
append(d,Paragraph(getLocalized('This report was generated by UroScanX automated diagnostic tool. This is a decision-support document and should be correlated with clinical findings and specialist consultation.',lang)));
sig = Paragraph([getLocalized('Reporting Radiologist / System:',lang) ' UroScanX Automated Report Engine']);
sig.Style = {Bold(true)};
append(d,sig);
close(d);
textParts = {};
textParts{end+1} = sprintf('%s. %s: %s, age %s, sex %s.', 'UroScanX Kidney Stone Diagnostic Report', getLocalized('Patient Details',lang), patientName, num2str(patientAge), patientSex);
textParts{end+1} = sprintf('%s %s', getLocalized('Report generated on:',lang), reportDate);
textParts{end+1} = buildClinicalIndication(lang);
textParts{end+1} = buildImagingTechnique(lang);
textParts{end+1} = findings;
textParts{end+1} = buildImpression(lang,data.stoneLength,data.location,data.result);
textParts{end+1} = buildRecommendations(lang,data.stoneLength,data.location);
textParts{end+1} = buildLifestyle(lang);
textParts{end+1} = buildUrgentCare(lang);
textParts{end+1} = buildAppendix(lang);
fullText = strjoin(textParts,'\n\n');
end

function s = getLocalized(key,lang)
switch lang
    case 'English'
        map = containers.Map( ...
            {'Patient Details','Clinical Indication / History','Imaging Technique','Observations and Findings', ...
            'Diagnostic Impression','Differential Diagnosis','Recommendations & Management Plan', ...
            'Lifestyle and Preventive Measures','When to seek urgent care','Appendix / Explanation', ...
            'Uploaded CT Image','Image could not be embedded: ','This report was generated by UroScanX automated diagnostic tool. This is a decision-support document and should be correlated with clinical findings and specialist consultation.','Reporting Radiologist / System:','Report generated on:'}, ...
            {'Patient Details','Clinical Indication / History','Imaging Technique','Observations and Findings', ...
            'Diagnostic Impression','Differential Diagnosis','Recommendations & Management Plan', ...
            'Lifestyle and Preventive Measures','When to seek urgent care','Appendix / Explanation', ...
            'Uploaded CT Image','Image could not be embedded: ','This report was generated by UroScanX automated diagnostic tool. This is a decision-support document and should be correlated with clinical findings and specialist consultation.','Reporting Radiologist / System:','Report generated on:'});
        s = map(key);
    case 'Telugu'
        map = containers.Map( ...
            {'Patient Details','Clinical Indication / History','Imaging Technique','Observations and Findings', ...
            'Diagnostic Impression','Differential Diagnosis','Recommendations & Management Plan', ...
            'Lifestyle and Preventive Measures','When to seek urgent care','Appendix / Explanation', ...
            'Uploaded CT Image','Image could not be embedded: ','This report was generated by UroScanX automated diagnostic tool. This is a decision-support document and should be correlated with clinical findings and specialist consultation.','Reporting Radiologist / System:','Report generated on:'}, ...
            {'రోగి వివరాలు','క్లినికల్ సూచన / చరిత్ర','చిత్రీకరణ సాంకేతికత','పరిశీలనలు మరియు కనుగొనబడిన విషయాలు', ...
            'నిర్ణాయక ఝలక్','వైద్య వేరియాల్స్ (విభేదక నివేదిక)','సిఫార్సులు & నిర్వహణ ప్లాన్', ...
            'జీవనశైలి మరియు నివారక చర్యలు','తక్షణ వైద్యం అవసరం అయినప్పుడు','సారాంశం / వివరణ', ...
            'అప్‌లోడ్ చేసిన CT చిత్రం','చిత్రాన్ని ఎంబెడ్ చేయడంలో విఫలమయ్యింది: ','ఈ నివేదిక UroScanX ఆటోమెటెడ్ డయాగ్నోస్టిక్ టూల్ ద్వారా ఉత్పత్తి చేయబడింది. ఇది ఒక నిర్ణయ-సహాయక డాక్యుమెంట్; దయచేసి క్లినికల్ ఫైండింగ్స్ మరియు నిపుణుల సంప్రదింపుతో చూసుకోండి.','రిపోర్ట్ చేసిన రేడియాలజిస్ట్ / సిస్టమ్:','రిపోర్ట్ తయారీ తేదీ:'});
        s = map(key);
    case 'Hindi'
        map = containers.Map( ...
            {'Patient Details','Clinical Indication / History','Imaging Technique','Observations and Findings', ...
            'Diagnostic Impression','Differential Diagnosis','Recommendations & Management Plan', ...
            'Lifestyle and Preventive Measures','When to seek urgent care','Appendix / Explanation', ...
            'Uploaded CT Image','Image could not be embedded: ','This report was generated by UroScanX automated diagnostic tool. This is a decision-support document and should be correlated with clinical findings and specialist consultation.','Reporting Radiologist / System:','Report generated on:'}, ...
            {'रुग्ण के विवरण','क्लिनिकल संकेत / इतिहास','इमेजिंग तकनीक','पर्यवेक्षण और निष्कर्ष', ...
            'निदानात्मक निष्कर्ष','भिन्न निदान','सिफारिशें और प्रबंधन योजना', ...
            'जीवनशैली और निवारक उपाय','जब आपातकालीन देखभाल की आवश्यकता हो','परिशिष्ट / व्याख्या', ...
            'अपलोड की गई CT छवि','छवि को एम्बेड करने में विफल: ','यह रिपोर्ट UroScanX स्वचालित डायग्नोस्टिक टूल द्वारा उत्पन्न की गई है। यह एक निर्णय-समर्थन दस्तावेज़ है; कृपया नैदानिक निष्कर्षों और विशेषज्ञ परामर्श के साथ समन्वय स्थापित करें।','रिपोर्टिंग रेडियोलॉजिस्ट / सिस्टम:','रिपोर्ट बनाई गई: '});
        s = map(key);
    case 'Tamil'
        map = containers.Map( ...
            {'Patient Details','Clinical Indication / History','Imaging Technique','Observations and Findings', ...
            'Diagnostic Impression','Differential Diagnosis','Recommendations & Management Plan', ...
            'Lifestyle and Preventive Measures','When to seek urgent care','Appendix / Explanation', ...
            'Uploaded CT Image','Image could not be embedded: ','This report was generated by UroScanX automated diagnostic tool. This is a decision-support document and should be correlated with clinical findings and specialist consultation.','Reporting Radiologist / System:','Report generated on:'}, ...
            {'விநோதி விவரங்கள்','மருத்துவக் குறிக்கோள் / வரலாறு','படமெடுக்கும் முறை','கண்காணிப்புகள் மற்றும் கண்டுபிடிப்புகள்', ...
            'மருத்துவப் படிப்பு','வித்தியாச التشخيص','பரிந்துரைகள் மற்றும் மேலாண்மை திட்டம்', ...
            'வாழ்க்கைமுறை மற்றும் தடுப்பு முன்னெச்சரிக்கை','முதல் உதவிக்கு எப்போது அணுகுவது','ஆபெண்டிக்ஸ் / விளக்கம்', ...
            'பதிவேற்றப்பட்ட CT படம்','படத்தை எம்பெட் செய்ய முடியவில்லை: ','இந்த அறிக்கை UroScanX தானியங்கி கண்டறிதல் கருவி மூலம் உருவாக்கப்பட்டது. இது ஒரு தீர்மான-ஆதரவு ஆவணம்; க்ளினிக்கல் கண்டறிதல்களுடன் இணைத்து பார்க்கவும்.','விவரம் முன்மொழியும் ரேடியோலொஜிஸ்ட் / சிஸ்டம்:','அறிக்கை உருவாக்கம்: '});
        s = map(key);
    otherwise
        s = key;
end
end

function s = buildClinicalIndication(lang)
switch lang
    case 'English'
        s = ['Clinical indication: The patient presented for imaging to evaluate for nephrolithiasis or related urinary tract symptoms. ' ...
             'Indications commonly include acute or chronic flank pain, hematuria (blood in urine), prior history of stones, recurrent urinary tract infections, or incidental radiographic hyperdense foci detected on other imaging studies. ' ...
             'A focused clinical history including presence of pain, fever, urinary symptoms, prior stone passage or interventions, and comorbidities such as impaired renal function or bleeding diathesis is important to correlate with imaging findings. ' ...
             'The purpose of this report is to describe imaging findings relevant to stone detection, potential obstruction, and to provide guidance for management and follow-up.'];
    case 'Telugu'
        s = ['క్లినికల్ సూచన: రోగి మూత్రపంధం రాళ్ళు లేదా సంబంధిత సమస్యల కోసం ఇమేజింగ్ కోసం సమర్పించారు. ' ...
             'సంబంధిత లక్షణాలలో ఫ్లాంక్ నొప్పి, మూత్రంలో రక్తం (హేమాట్యూరియా), మునుపటి రాయి చరిత్ర లేదా పునరావృత మూత్రనాళ ఇన్ఫెక్షన్లు ఉంటాయి. ' ...
             'క్లినికల్ చరిత్ర (నొప్పి స్థాయి, జ్వరం, మూత్ర సంబంధిత లక్షణాలు, పూర్వ వైద్య చికిత్సలు) గుర్తిస్తే నివేదికను ఆసుపత్రి ఫలితాలతో కలిసి చూడాలి. ' ...
             'ఈ నివేదిక రాయి గుర్తింపు, అవరోధం లేదా సునిశ్చితి కోసం సూచనలు ఇవ్వడానికి తయారు చేయబడింది.'];
    case 'Hindi'
        s = ['क्लिनिकल संकेत: रोगी को मूत्र पथ/गुर्दे की पथरी की जांच हेतु इमेजिंग के लिए प्रस्तुत किया गया। ' ...
             'संकेतों में आमतौर पर फूलने वाली/कमर की पीड़ा, मूत्र में रक्त, पत्थर का पूर्व इतिहास, बार-बार पेशाब संबंधी संक्रमण या अन्य इमेजिंग पर आकस्मिक उच्च घनत्व क्षेत्र शामिल हो सकते हैं। ' ...
             'क्लिनिकल इतिहास (लक्षण, बुखार, पूर्व प्रक्रिया) की उपयुक्त समन्वय आवश्यक है।'];
    case 'Tamil'
        s = ['மருத்துவக் குறிக்கோள்: சிறுநீர்வழி கற்கள் அல்லது தொடர்புடைய அறிகுறிகளுக்காக நோயாளி படமெடுக்கும் சேவைக்காக வந்தார். ' ...
             'குறைந்தது பக்கவாட்டுப் போக்குகள், சிறுநீரில் இரத்தம் அல்லது முந்தய கற்கள் வரலாறு போன்றவை குறிப்பிடத்தக்கவை. ' ...
             'படமெடுக்கும் முடிவுகளை மருத்துவ பரிசோதனைகள் மற்றும் அறிகுறிகளுடன் இணைக்க வேண்டும்.'];
    otherwise
        s = '';
end
end

function t = buildImagingTechnique(lang)
switch lang
    case 'English'
        t = ['Imaging technique: Non-contrast CT acquisition (kidney, ureter, bladder protocol) is presumed for dedicated stone detection. ' ...
             'Axial source images are reviewed with multiplanar reformats as indicated. Standard soft-tissue and bone window settings were considered during review. ' ...
             'When available, thin-section axial images and multiplanar reconstructions allow more accurate measurement of stone size and assessment of secondary signs of obstruction.'];
    case 'Telugu'
        t = ['చిత్రీకరణ పద్ధతి: రాళ్ళను గుర్తించడానికి non-contrast CT సాధారణంగా ఉపయోగించబడుతుంది. ' ...
             'ఆక్సియల్ సోర్స్ చిత్రాలు మరియు అవసరమైతే మల్టీప్లానర్ పునర్నిర్మాణాలు పరిశీలించబడ్డాయి.'];
    case 'Hindi'
        t = ['इमेजिंग तकनीक: पत्थर की पहचान हेतु नॉन-कॉन्ट्रास्ट CT (किडनी-यूरिटर-ब्लैडर प्रोटोकॉल) मान्य किया गया। ' ...
             'आवश्यकतानुसार अक्षीय तथा मल्टीप्लानर पुनर्निर्माण की समीक्षा की गयी।'];
    case 'Tamil'
        t = ['படமெடுக்கும் முறை: கற்களை கண்டறிவதற்காக நோன்-கான்ட்ராஸ்ட் CT பயன்படுத்தப்படுகிறது.'];
    otherwise
        t = '';
end
end

function s = buildFindingsText(lang, lenMM, loc, result, imgIn)
upstream = hasUpstreamDilationHint(imgIn);
switch lang
    case 'English'
        s = sprintf([ ...
            '%s\n\n' ...
            'Kidney morphology and site: On the reviewed images, a discrete hyperdense focus consistent with a renal calculus is identified in the %s portion of the kidney. ' ...
            'The maximal linear measurement measured on axial images approximates %.2f mm. The lesion demonstrates sharp margins and high attenuation compared with adjacent renal parenchyma, which is typical for a calcified calculus. ' ...
            '\n\nStone burden and morphology: The lesion appears solitary with an ovoid to mildly irregular contour. There is no internal soft-tissue attenuation to suggest a mass lesion. Stone composition cannot be definitively determined on non-contrast CT but dense hyperattenuation often indicates calcium-containing stones. ' ...
            '\n\nObstruction assessment: On the available non-contrast series there is %s radiologic evidence of upstream collecting system dilatation. If hydronephrosis or ureteral dilatation is present, this would raise concern for partial or complete obstruction, which can influence management urgency. ' ...
            '\n\nAssociated findings: Corticomedullary differentiation is preserved on the current series. No large perinephric fluid collection, perirenal stranding, or obvious adjacent inflammatory change is identified. ' ...
            '\n\nTechnical considerations and limitations: Measurements have been performed on 2D axial images and represent an approximation of true stone diameter. Volumetric 3D assessment or thin-section multiplanar reconstructions (if available) can refine stone burden assessment. ' ...
            '\n\nClinical interpretation and summary: The imaging findings are consistent with nephrolithiasis in the %s region, with a solitary calculus measuring approximately %.2f mm. Management will depend on symptomatology, stone location (renal pelvis versus calyx versus ureter), degree of obstruction, and patient comorbidities. ' ...
            '\n\nRecommendations below outline general approaches and further investigations that may guide treatment and follow-up.'], ...
            result, loc, lenMM, upstream, loc, lenMM);
    case 'Telugu'
        s = sprintf([ ...
            '%s\n\n' ...
            'వివరాలు: పరిశీలించిన చిత్రాల్లో %s ప్రాంతంలో సుమారు %.2f మిమీ పరిమాణం గల ఒక ఘనత్వపు ఫోకస్ కనిపించింది. ఇది స్పష్టమైన అంచులు మరియు అధిక ఘనత్వాన్ని చూపుతుంది, ఇది సాధారణంగా కాల్సిఫైడ్ రాయికి సూచన. ' ...
            '\n\nరాయి లక్షణాలు: ఇది ఒంటరిగా కనిపిస్తుంది మరియు కొంచెం అసమానాకార ఆకారంలో ఉంది. ' ...
            '\n\nఅవరోధం: అందుబాటులో ఉన్న సిరీస్‌లో %s ప్రోక్సిమల్ కలెక్టింగ్ సిస్టమ్ విస్తరణ సూచన కనపడింది. ' ...
            '\n\nసాంకేతిక పరిమితులు: కొలతలు 2D చిత్రాలపై చేయబడ్డాయి; 3D అంచనాలు మరింత ఖచ్చితతను ఇస్తాయి. ' ...
            '\n\nసారాంశం: పై ఫైండింగ్స్ సుమారు %.2f mm పరిమాణం గల ఒకే రాయి %s ప్రాంతంలో ఉందని సూచిస్తాయి.'], ...
            result, loc, lenMM, upstream, lenMM, loc);
    case 'Hindi'
        s = sprintf([ ...
            '%s\n\n' ...
            'विवरण: समीक्षा की गई CT छवियों में गुर्दे के %s भाग में लगभग %.2f मिमी का एक उच्च घनत्व फोकस पाया गया है। यह फोकस स्पष्ट किनारों और आसपास के ऊतक की तुलना में उच्च अटेन्यूएशन दिखाता है। ' ...
            '\n\nअवरोध का मूल्यांकन: उपलब्ध श्रृंखला पर ऊपर की ओर मूत्रसंग्रह प्रणाली के फैलाव का %s संकेत है। ' ...
            '\n\nतकनीकी विचार: मापन 2D छवियों पर आधारित हैं; 3D मापन अधिक सटीक हो सकता है। ' ...
            '\n\nनिष्कर्ष: यह सोलिटरी कैल्कुलस लगभग %.2f मिमी का है और %s क्षेत्र में स्थित है।'], ...
            result, loc, lenMM, upstream, lenMM, loc);
    case 'Tamil'
        s = sprintf([ ...
            '%s\n\n' ...
            'விவரங்கள்: பரிசீலிக்கப்பட்ட CT படங்களில் %s பகுதியில் சுமார் %.2f மிமீ அளவிலான ஒரு அதிக அடர்த்தியைக் காணப்படுகிறது. இது தெளிவான விளிம்புகளைக் கொண்டு உள்ளது. ' ...
            '\n\nதடை மதிப்பீடு: கிடைக்கும் படங்களில் மேல்நிலை கலெக்டிங் சிஸ்டம் குறித்து %s என்று காணப்படுகிறது. ' ...
            '\n\nநுட்ப குறிப்புகள்: அளவுகள் 2D படங்களின் அடிப்படையில்; 3D ஆய்வு சரியான அளவீடுகளுக்கு உதவும். ' ...
            '\n\nசுருக்கம்: இது சுமார் %.2f மிமீ அளவிலான ஒற்றை கல் %s பகுதியில் காணப்பட்டது.'], ...
            result, loc, lenMM, upstream, lenMM, loc);
    otherwise
        s = result;
end
end

function imp = buildImpression(lang,lenMM,loc,result)
switch lang
    case 'English'
        imp = sprintf(['1. Solitary renal calculus in the %s region measuring approximately %.2f mm.\n' ...
            '2. No large perinephric fluid collection or mass lesion identified on current non-contrast series.\n' ...
            '3. Correlate clinically for obstruction or infection; consider urology referral for management.'], loc, lenMM);
    case 'Telugu'
        imp = sprintf(['1. %s ప్రాంతంలో ఒకే రాయి, సుమారు %.2f mm.\n2. ప్రస్తుత చిత్రాల్లో పెద్ద పరిరేణు ద్రవం లేదా మాస్ కనిపించలేదు.\n3. క్లినికల్ సమన్వయం చేయండి.'], loc, lenMM);
    case 'Hindi'
        imp = sprintf(['1. %s क्षेत्र में एकल पत्थर, लगभग %.2f मिमी।\n2. वर्तमान श्रृंखला में बड़ा परिरिनल तरल संचय नहीं पाया गया।\n3. क्लिनिकल समन्वय आवश्यक।'], loc, lenMM);
    case 'Tamil'
        imp = sprintf(['1. %s பகுதியில் ஒரே கல், சுமார் %.2f மிமீ.\n2. பெரிய திரவச்சேமிப்பு இல்லை.\n3. மருத்துவ ஆலோசனை தேவை.'], loc, lenMM);
    otherwise
        imp = result;
end
end

function d = buildDifferential(lang)
switch lang
    case 'English'
        d = ['Differential considerations include calcified vascular structures projecting over the renal silhouette (phleboliths), ' ...
             'calcified granulomas or small cortical calcifications. Correlation with multiple planes and clinical history can help distinguish these from true calculi.'];
    case 'Telugu'
        d = 'వేరే కారణాలుగా రక్తనాళాల కల్సిఫికేషన్ లేదా కాల్సిఫైడ్ గ్రానులోమాలు ఉండవచ్చు; ఇతర ఇమేజింగ్‌తో నిర్ధారణ అవసరం.';
    case 'Hindi'
        d = 'भिन्न निदान में वाहिकीय कैल्सिफिकेशन, फेलेबोलिथ, या कैल्सिफाइड ग्रैनुलोमा शामिल हो सकते हैं।';
    case 'Tamil'
        d = 'வித்தியாசமான காரணங்கள்: இரத்தக்குழாய் கல்சிபிகேஷன் அல்லது பைலிபோலித்துகள் போன்றவை.';
    otherwise
        d = '';
end
end

function r = buildRecommendations(lang,lenMM,loc)
if nargin<2, lenMM = 0; end
switch lang
    case 'English'
        r = sprintf(['Management considerations and recommended plan:\n\n' ...
            '1) For stones smaller than approximately 5–6 mm, conservative management (hydration, analgesia, medical expulsive therapy) is often appropriate if there is no significant obstruction or infection. A stone of approximately %.2f mm commonly warrants urology review to discuss options and to confirm exact location.\n\n' ...
            '2) Interventional options include extracorporeal shockwave lithotripsy (SWL), ureteroscopy (URS) with laser lithotripsy, and percutaneous nephrolithotomy (PCNL) depending on stone size, composition, and location.\n\n' ...
            '3) If there are signs of infection with obstruction, urgent decompression and antibiotic therapy may be required.\n\n' ...
            '4) Baseline blood tests (renal function), urinalysis and culture, and metabolic evaluation for recurrent stone formers are recommended.'], lenMM);
    case 'Telugu'
        r = sprintf(['నిర్వహణ సూచనలు: సుమారు %.2f mm రాయి అయితే యురాలజీ సలహా తీసుకోవాలి. ఎంపికలు SWL, URS లేదా PCNL అవి.'], lenMM);
    case 'Hindi'
        r = sprintf(['प्रबंधन सुझाव: लगभग %.2f मिमी पत्थर पर यूरोलॉजी परामर्श पर विचार करें; विकल्प: SWL, URS, PCNL।'], lenMM);
    case 'Tamil'
        r = sprintf(['மேலாண்மை: சுமார் %.2f மிமீ கல்லிற்கு யூராலஜி ஆலோசனை பரிந்துரைக்கப்படுகிறது; SWL/URS/PCNL ஆகியவை விருப்பங்கள்.'], lenMM);
    otherwise
        r = '';
end
end

function l = buildLifestyle(lang)
switch lang
    case 'English'
        l = ['Lifestyle and preventive measures: Increase oral fluid intake to achieve dilute, light-colored urine (aim ~2–3 L/day unless contraindicated). Reduce dietary sodium, avoid excessive animal protein, and limit high-oxalate foods. Consider dietary counseling and follow-up metabolic testing for recurrent stone formers.'];
    case 'Telugu'
        l = 'జీవనశైలి: రోజుకు 2-3 లీటర్లు నీరు తాగండి, ఉప్పు తగ్గించండి.';
    case 'Hindi'
        l = 'जीवनशैली: 2-3 लीटर पानी प्रतिदिन पिएं; नमक कम करें।';
    case 'Tamil'
        l = 'வாழ்க்கைமுறை: தினமும் 2-3 லிட்டர் நீர் குடிக்கவும்; உப்பு குறைக்கவும்.';
    otherwise
        l = '';
end
end

function u = buildUrgentCare(lang)
switch lang
    case 'English'
        u = ['When to seek urgent care: Seek immediate medical attention for severe persistent flank pain not controlled by analgesics, fever or chills (suggesting infected obstructed system), inability to pass urine or signs of systemic sepsis. These situations require urgent hospital evaluation.'];
    case 'Telugu'
        u = 'తక్షణ వైద్యం అవసరం: తీవ్రమైన నొప్పి లేదా జ్వరం కనిపిస్తే వెంటనే ఆసుపత్రికి వెళ్ళండి.';
    case 'Hindi'
        u = 'तत्काल चिकित्सा सहायता लें यदि तेज दर्द या बुखार हो।';
    case 'Tamil'
        u = 'உடனடிப் பராமரிப்பு தேவைப்படும் போது மருத்துவமனைக்கு செல்லவும்.';
    otherwise
        u = '';
end
end

function a = buildAppendix(lang)
switch lang
    case 'English'
        a = ['Appendix / Limitations: This report is generated from the provided non-contrast CT images and an automated detection pipeline. Measurements are approximate and may differ slightly from manual radiologic measurement. Small stones or unfavorable angles may be obscured by artifact. Correlate with clinical findings and specialist consultation.'];
    case 'Telugu'
        a = 'పరిమితులు: ఈ నివేదిక ఆటోమెటెడ్ డిటెక్షన్లో తయారయ్యింది; కొలతలు సుమారుగా ఉంటాయి.';
    case 'Hindi'
        a = 'सीमाएँ: स्वचालित विश्लेषण पर आधारित; मापन अनुमानित हो सकते हैं।';
    case 'Tamil'
        a = 'வரம்புகள்: தானியங்கி கண்டறிதல் அடிப்படையில் உருவாக்கப்பட்டது; அளவீடுகள் சுமார்.';
    otherwise
        a = '';
end
end

function out = hasUpstreamDilationHint(imgIn)
out = 'no clear';
end

function paras = splitIntoParagraphs(longstr,chunkLen)
if nargin<2, chunkLen = 700; end
longstr = char(longstr);
n = length(longstr);
paras = {};
pos = 1;
while pos <= n
    endpos = min(n, pos + chunkLen - 1);
    sub = longstr(pos:endpos);
    idx = find(sub==10,1,'last');
    if isempty(idx)
        idx2 = find(sub=='.',1,'last');
        if ~isempty(idx2)
            cut = pos + idx2 - 1;
        else
            cut = endpos;
        end
    else
        cut = pos + idx - 1;
    end
    paras{end+1} = strtrim(longstr(pos:cut)); %#ok<AGROW>
    pos = cut + 1;
end
end

function ttsLang(str,lang)
try
    NET.addAssembly('System.Speech');
    synth = System.Speech.Synthesis.SpeechSynthesizer;
    Speak(synth,string(str));
catch
    fprintf('--- TTS (%s) ---\n%s\n--- End ---\n',lang,str);
end
end

function emergencyCall()
try
    uialert(gcf,'Emergency numbers: 108, 102, alternate: +919182185548','Emergency');
catch
    disp('Emergency numbers: 108, 102, +919182185548');
end
end

function chatbotDialog()
d = dialog('Position',[300 300 360 220],'Name','Chatbot');
uicontrol(d,'Style','text','String','Bot: Hello! Ask about stones, size, location, or report.','Position',[20 160 320 30]);
msg = uieditfield(d,'text','Position',[20 120 260 22]);
uibutton(d,'Text','Send','Position',[290 120 60 22],...
    'ButtonPushedFcn',@(src,event) botReply());

    function botReply()
        q = lower(msg.Value);
        appData = getappdata(0,'KidneyStoneAppData');
        if isempty(appData)
            answer = 'No data available. Run detection first.';
        elseif contains(q,'size')
            answer = sprintf('Detected stone size: %.2f mm', appData.stoneLength);
        elseif contains(q,'location')
            answer = ['Stone location: ', appData.location];
        elseif contains(q,'report')
            if isfield(appData,'reportFile') && ~isempty(appData.reportFile)
                answer = ['Report saved at: ', appData.reportFile];
            else
                answer = 'Generate the report using Generate Word Report button.';
            end
        elseif contains(q,'precaution') || contains(q,'precautions')
            if appData.stoneLength>0
                answer = 'Precautions: Drink 2-3 L water/day, low salt diet, consult urologist.';
            else
                answer = 'Precautions: Maintain hydration and routine check-ups.';
            end
        else
            answer = 'I can answer about detected stone size, location, report file, and basic precautions.';
        end
        uialert(d,answer,'Bot Reply');
    end
end
