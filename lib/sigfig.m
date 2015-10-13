%[strOut2] = sigfig(matNum, nSigFig, strPad)
%Rounds number to nSigFig number of significant figures and outputs a string
%'pad' in 3rd argument to have padded zeros, else unpadded
%if number of arguments < 3, then choose shorter output, between padded and unpadded
%if number of arguments < 2, then 3 significant figures
%Lim Teck Por, 2006, 2008, 2009
%Apropos: mat2str, num2str, sprintf

function [strOut2] = sigfig(matNum, nSigFig, strPad)
[N, D] = size(matNum);
if (nargin < 2)
    nSigFig = 3;
end
if (nargin < 3)
    strPad = [];
end

strOut2 = [];
for l = 1:N
    for k = 1:D
        numkl = matNum(l,k);
        if (isnan(numkl)||isinf(numkl)) %if nan or inf
            strOut = num2str(numkl);
            mySign = [];
        else %if neither nan or inf
            if (sign(numkl) == -1)
                mySign = '-';
            else
                mySign = [];
            end
            num = abs(numkl);
            nSigFig1 = nSigFig - 1;
            strFormat = ['%1.',(num2str(nSigFig+2)),'e'];

            strTemp = sprintf(strFormat, num);
            [strPrefix,strExponent] = strtok(strTemp, 'e');
            strExponent = strExponent(2:end);
            strFactor = num2str(nSigFig1);
            nTemp = str2num([strPrefix, 'e', strFactor]);
            nExponent = str2num(strExponent);
            fTemp = str2num([num2str(round(nTemp)), 'e', num2str(nExponent-nSigFig1)]);

            strTemp = sprintf(strFormat, fTemp);
            [strPrefix,strExponent] = strtok(strTemp, 'e');
            strExponent = strExponent(2:end);
            while (strExponent(2) == '0') && (length(strExponent) > 2)
                strExponent = [strExponent(1), strExponent(3:end)];
            end
            [strPrefix2,strSuffix2] = strtok(strPrefix, '.');
            strSuffix2 = strSuffix2(2:end);
            if (str2num(strSuffix2(nSigFig)) >= 5)
                nTemp = str2num([strPrefix2,strSuffix2(1:nSigFig1)])+1;
                strTemp2 = num2str(nTemp);
                strPrefix2 = strTemp2(1);
                strSuffix2 = strTemp2(2:end);
            else
                strSuffix2(nSigFig:end) = [];
            end
            if (nargin < 3) %if zero padding
                strOuta = zeroPadding(strPrefix2, strSuffix2, strExponent, nSigFig, num, strPad);
                if (nSigFig1 == 0)
                    strOutb = [strPrefix2, strSuffix2, 'e', strExponent];
                else
                    strOutb = [strPrefix2, '.', strSuffix2, 'e', strExponent];
                end
                if(length(strOuta)<length(strOutb))
                    strOut = strOuta;
                else
                    strOut = strOutb;
                end
            else %if no zero padding
                if (strcmp(strPad,'pad'))
                    strOut = zeroPadding(strPrefix2, strSuffix2, strExponent, nSigFig, num, strPad);
                else
                    if (nSigFig1 == 0)
                        strOut = [strPrefix2, strSuffix2, 'e', strExponent];
                    else
                        strOut = [strPrefix2, '.', strSuffix2, 'e', strExponent];
                    end
                end
            end %if no zero padding
            if (strOut(end)=='.')
                strOut = strOut(1:end-1);
            end
            if (length(strOut) > 5)
                if (strcmpi(strOut(end-2:end), 'e+0'))
                    strOut = strOut(1:end-3);
                end
            end
        end %if neither nan or inf
        strOut2 = [strOut2, mySign, strOut];
        if (k<D)
            strOut2 = [strOut2, ','];
        end
    end
    if (l<N)
        strOut2 = [strOut2, ';'];
    else
        strOut2 = sprintf('%s', strOut2);
    end
end

function [strOut] = zeroPadding(strPrefix2, strSuffix2, strExponent, nSigFig, num, strPad)
nDP = str2num(strExponent);
if (nDP < 0) %nDP < 0
    strZeros = char(repmat(48,1,abs(nDP)-1));
    strOut = ['0.', strZeros, strPrefix2, strSuffix2];
else %nDP >= 0
    nP = length(strPrefix2);
    nS = length(strSuffix2);
    nPad =  nSigFig - nP - nS;
    if (nPad > 0)
        strZeros = char(repmat(48,1,nPad));
    else
        strZeros = [];
    end
    if (nDP == 0) %nDP = 0
        strOut = [strPrefix2, '.', strSuffix2, strZeros];
    else %nDP > 0
        %nOut = str2num([strPrefix2, '.', strSuffix2]);
        %strOut = num2str(nOut*10^nDP);
        nPad1 = nDP - nS;
        strZeros1 = char(repmat(48,1,nPad1));
        strTemp = [strSuffix2, strZeros1];
        strOut = [strPrefix2, strTemp(1:nDP), '.', strTemp(nDP+1:end)];
        nPad2 = nSigFig - length(strOut);
        if (nPad2 > 0)
            strZeros2 = char(repmat(48,1,nPad2));
            strOut = [strOut, '.', strZeros2];
        end
    end %nDP > 0
end %nDP >= 0
