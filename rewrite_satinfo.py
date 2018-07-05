import numpy as np
import collections
import sys

# rewrite satinfo file, changing some columns

infile = sys.argv[1]
outfile = sys.argv[2]

infodict = collections.OrderedDict()
for line in open(infile):
    if not line.startswith('!'):
        values = line.split()
        infodict[values[0]] = collections.OrderedDict()
for line in open(infile):
    if not line.startswith('!'):
        values = line.split()
        infodict[values[0]][values[1]] = list(values[2:])
    else:
        topline = line
        keys = line[1:].split()
n = keys.index('#')
keys = keys[2:n]
iuse_indx = keys.index('iuse')
ermax_indx = keys.index('ermax')
for satsensor in infodict.keys():
    for channel in infodict[satsensor].keys():
        # change iuse and ermax for these instruments, channels.
        #if satsensor.startswith('amsua') and channel in ['11','12','13','14']:
        if satsensor.startswith('amsua') and channel in ['13','14']:
            iuse_rad = infodict[satsensor][channel][iuse_indx]
            ermax = infodict[satsensor][channel][ermax_indx]
            if iuse_rad == '1': 
                 # change iuse
                 infodict[satsensor][channel][iuse_indx] = '2'
                 # boost ermax
                 infodict[satsensor][channel][ermax_indx] = '%5.3f' % (float(ermax) + 0.0,)
            #print satsensor,channel,infodict[satsensor][channel],iuse_rad,ermax

# write out new file.
f = open(outfile,'w')
f.write(topline)
for satsensor in infodict.keys():
    for channel in infodict[satsensor].keys():
        out_tuple = (satsensor, channel) + tuple(infodict[satsensor][channel])
        f.write(' %-19s%4s   %2s    %5s   %6s    %5s  %7s    %5s     %2s     %2s     %2s\n' % out_tuple)
f.close()
