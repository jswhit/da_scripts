import sys,os
from subprocess import Popen, PIPE
def parse_nodelist(nodeexp):
    # Convert the compressed nodelist expression into an array
    p = Popen(['scontrol', 'show', 'hostnames', nodeexp], stdout=PIPE, stderr=PIPE)
    (sout, serr) = p.communicate()
    sout = sout.decode('ascii'); serr = serr.decode('ascii')
    if p.returncode != 0:
        errexit("Unable to parse nodelist: error %d: %s" % (p.returncode, serr.rstrip()))
    nodelist = sout.rstrip().split('\n')
    return nodelist
nodeexp     = os.environ['SLURM_JOB_NODELIST']
tasks_root_node = 1 # just one task on root node
tasks_other_nodes = int(sys.argv[1]) # this many tasks on other nodes
slurm_hostfile = sys.argv[2] # create SLURM_HOSTFILE with this name
f = open(slurm_hostfile,'w')
nodelist = parse_nodelist(nodeexp)
nnode = 0
for node in nodelist:
    nnode += 1
    if nnode == 1:
        f.write('%s\n' % node)
    else:
        for n in range(tasks_other_nodes):
            f.write('%s\n' % node)
f.close()
