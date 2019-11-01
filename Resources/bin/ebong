#!/usr/bin/env python
# look in newbong
import sre
A='A'
B='B'
S='S'
s='s'
F='F'
X='X'

NCLINE = 0
global NCWORD,CWORD

AKSAR={
        'k'   :[B,'k'],
        'kh'  :[B,'kh'],
        'g'   :[B,'g'],
        'gh'  :[B,'gh'],
        'ng'  :[B,'NG'],

        'ch'  :[B,'c'],
        '^ch' :[B,'ch'],
        'j'   :[B,'j'],
        'jh'  :[B,'jh'],
        '^y'  :[B,'NJ'],
        '_n'  :[B,'NJ'],

        't'   :[B,'T'],
        '^th' :[B,'Th'],
        'd'   :[B,'D'],
        'dh'  :[B,'Dh'],
        '^n'  :[B,'N'],

        '_t'  :[B,'t'],
        'th' :[B,'th'],
        '_d'  :[B,'d'],
        '_dh' :[B,'dh'],
        'n'   :[B,'n'],

        'p'   :[B,'p'],
        'ph'  :[B,'ph'],
        'f'   :[B,'ph'],
        'b'   :[B,'b'],
        'bh'  :[B,'bh'],
        'v'   :[B,'bh'],
        'm'   :[B,'m'],
        'M'   :[F,'M'],

        '^j'  :[B,'J'],
        'J'   :[B,'J'],
        'r'   :[B,'r'],
        'R'   :[F,'R'],
        'l'   :[B,'l'],
        'L'   :[F,'L'],
        'W'   :[F,'W'],
        'V'   :[F,'W'],
        'h'   :[B,'H'],
        'kk'  :[B,'kK'],
        'kkm' :[B,'kK/N'],

        'sh'  :[B,'sh'],
        '^s'  :[B,'Sh'],
        '^sh' :[B,'Sh'],
        's'   :[B,'s'],

        '^r'   :[B,'rh'],
        '^rh'  :[B,'rhh'],
        'y'    :[B,'y'],
        'Y'    :[F,'Y'],
        'JY'   :[F,'Y'],
        '__t'  :[B,'t//'],
        '^ng'  :[B,'NNG'],
        ':h'   :[B,'h'],
        '^'    :[F,'NN'],
        '_'    :[F,':/'],

        'A'    :[S,'A'],
        'AA'   :[S,'Aa'],
        'I'    :[S,'I'],
        'II'   :[S,'II'],
        'U'    :[S,'U'],
        'UU'   :[S,'UU'],
        'RI'   :[S,'RR'],
        'E'    :[S,'E'],
        'OI'   :[S,'OI'],
        'O'    :[S,'O'],
        'OU'   :[S,'OU'],

        'a'    :[X,'o',1],
        'aa'   :[s,'a',1],
        'i'    :[s,'i',-1],
        'ii'   :[s,'ii',1],
        'u'    :[s,'u',1],
        'uu'   :[s,'uu',1],
        'RII'   :[s,'rR',1],
        'e'    :[s,'e',-1],
        'oi'   :[s,'oi',-2],
        'oo'   :[s,'oo',11],
        'o'    :[X,'o',1],
        'ou'   :[s,'ou',12],

        '.'    :[F,'.'],
        '..'   :[F,'..'],
        '...'  :[F,'...'],
        '|'    :[F,'|'],

        '~'    :[F,'~'],
        '`'    :[F,'`'],
        '!'    :[F,'!'],
        '1'    :[F,'1'],
        '2'    :[F,'2'],
        'at'   :[F,'@'],
        '#'    :[F,'#'],
        '3'    :[F,'3'],
        '$'    :[F,'$'],
        '4'    :[F,'4'],
        '%'    :[F,'%'],
        '5'    :[F,'5'],
        '6'    :[F,'6'],
        '&'    :[F,'&'],
        '7'    :[F,'7'],
        '*'    :[F,'*'],
        '8'    :[F,'8'],
        '('    :[F,'('],
        '9'    :[F,'9'],
        ')'    :[F,')'],
        '0'    :[F,'0'],
        'dash' :[F,'-'],
        '+'    :[F,'+'],
        '='    :[F,'='],
        '|'    :[F,'|'],
        '{'    :[F,'{'],
        '['    :[F,'['],
        '}'    :[F,'}'],
        ']'    :[F,']'],
        ':'    :[F,':'],
        ';'    :[F,';'],
        '"'    :[F,'"'],
        "'"    :[F,"'"],
        '<'    :[F,'<'],
        ','    :[F,','],
        '>'    :[F,'>'],
        '.'    :[F,'.'],
        '?'    :[F,'?'],
        '/'    :[F,'/']}

CATCODES = {'SS'  :[S,'','','',1],
            'SB'  :[B,'','','',1],
            'BS'  :[S,'','','',1],
            'BB'  :[B,'','/','',1],
            'BF'  :[F,'','','',1],
            'Bs1' :[S,'','','',1],
            'Bs-1':[S,'\*','','*',1],
            'Bs-2':[S,'\*','','*{oi}',0],
            'Bs11':[S,'\*','','*ea',0],
            'Bs12':[S,'\*','','*eou',0],
            'Fs1' :[S,'','','',1],
            'Fs-1':[S,'\*','','*',1],
            'Fs-2':[S,'\*','','*{oi}',0],
            'Fs11':[S,'\*','','*ea',0],
            'Fs12':[S,'\*','','*eou',0],
            'FF'  :[F,'','','',1],
            'AX'  :[F,'','','',1]}

def blocked(line):
    #print '@ blocked', line , '->',
    m = sre.findall('@[^@]+@',line)
    outline = line
    if not m :
        #print  outline
        return(outline)
    else:
        for i in range(len(m)):
            s=m[i][:-1].replace(' ','%X%')
            outline = outline.replace(m[i],s,1)
        #print outline
        return(outline)

def unblock(line):
    #print '@unblock', line, '->',
    m = sre.findall('@[^\s]+',line)
    outline = line
    if not m :
        #print outline
        return(outline)
    else:
        for i in range(len(m)):
            s=m[i].replace('@','').replace('%X%',' ')
            outline = outline.replace(m[i],s)
        #print outline
        return(outline)

def printamp(line):
    #print '@unblock', line, '->',
    m = sre.findall('#AT',line)
    outline = line
    if not m :
        #print outline
        return(outline)
    else:
        for i in range(len(m)):
            outline = outline.replace('#AT','@')
        #print outline
        return(outline)

def  readsyll(syll):
    syllparts=[]
    start = 0; end = len(syll)
    while syll[start : end]:
	slice = syll[start : end]
	#print slice
	if AKSAR.has_key(slice):
		syllparts.append(AKSAR[slice])
		start = start + len(slice)
		end = len(syll)
	else :
		end = end -1
    return(syllparts)

def fuse(list1,list2):
    global CCATCODE
    #print list1,list2
    Type1 = list1[0]
    Type2 = list2[0]

    if Type2 == s:
       Type3 = str(list2[2])
    elif Type2 == X:
	Type1=A
	Type3=''
    else:
	Type3 =''

    Type = Type1+Type2+Type3

    #print 'Type:', Type

    try:
        CATCODE = CATCODES[Type]
        TARGET = CATCODE[0]
        PREFIX = CATCODE[1]
        MIDFIX = CATCODE[2]
        POSTFIX = CATCODE[3]
        FLAG = CATCODE[4]

        #print 'TGT:', TARGET, PREFIX,MIDFIX,POSTFIX,FLAG
        #print 'RAWC', AKSAR[list1[1]][1],AKSAR[list2[1]][1]

        c1=list1[1]
        c2=list2[1]

        if FLAG == 1 :
            c = PREFIX + c1 + MIDFIX + POSTFIX + c2
        else :
            c = PREFIX + c1 + MIDFIX + POSTFIX

        fused = [TARGET,c]
        #print CATCODE
        return(fused)
    except KeyError:
        print '\n ERROR AT LINE:', NCLINE, 'WORD:',NCWORD, '(',CWORD,')'
        return(['ERROR','UNKNOWN CATCODE'])

def fuseatoms(syll):
    slist=readsyll(syll);
    #print slist
    lslist=len(slist);
    l0=slist[0];
    for i in range(1,lslist):
        nextitem = slist[i]
        l0=fuse(l0,nextitem)

    return(l0[1])

def fuseword(wrd):
    if wrd[0] == '@' :
        return(wrd)
    syllables = wrd.split('-')
    w0=''
    for eachsyll in syllables:
        syll=eachsyll
        thesyll = fuseatoms(syll)
        w0 = w0 + thesyll
    #print 'FUSED WORD',w0
    return(w0)

def fuseline(line):
    global NCWORD,CWORD
    NCWORD = 0
    #line = blocked(line)
    words = line.split()
    l0=''
    for eachword in words:
        NCWORD=NCWORD+1
        word = eachword
        CWORD=word
        theword=fuseword(word)
        #print 'XX',theword
        l0=l0+' '+theword
    #print 'FUSED LINE', l0
    return(l0)

# The main program
import sys
OK=1
finnam = sys.argv[1]
foutnam = finnam.split('.')[0] + '.' + 'tex'

fin  = file(finnam,'rt')
fout = file(foutnam,'wt')

textin = fin.readlines()
nlines = len(textin)

textout = []

fin.close()

for eachline in textin:
                NCLINE = NCLINE+1
                if eachline[0] == '#' :
                    lineout = eachline[1:]
                elif eachline[0] == '\\' :
                    lineout = eachline
                elif eachline == '\n':
                    lineout = eachline
                else :
                    line1   = eachline.strip()
                    line2   = blocked(line1)
                    lineout = fuseline(line2) + '\n'
                    lineout = lineout[1:]
                    #print ':::', lineout
                if lineout.find('UNKNOWN CATCODE') == -1 :
                    lineout = unblock(lineout)
                    #print ':::', lineout
                    textout.append(printamp(lineout))
                else :
                    OK = 0
                    fout.close()

if OK == 1:
    fout.writelines(textout)
    fout.close()
    print 'done'
else:
    print 'Unknown CATCODE, Fix The errors and try again'
