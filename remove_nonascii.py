import sys
if len(sys.argv) < 3:
    raise SystemExit('remove_nonascii.py <infile> <outfile>')
fin = open(sys.argv[1]) # input text file
fout = open(sys.argv[2],'wb') # output text file w/out non-ascii lines
for line in fin:
    try:
        fout.write(line.encode('ASCII'))
    except UnicodeDecodeError:
        pass
fin.close()
fout.close()
