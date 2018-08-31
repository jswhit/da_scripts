program makeinc_nemsio
!$$$  main program documentation block
!
! program:  makeinc_nemsio
!
! prgmmr: whitaker         org: esrl/psd               date: 2009-02-23
!
! abstract:  difference two nemsio files
!
! program history log:
!   2009-02-23  Initial version.
!
! usage:
!   input files:
!
!   output files:
!
! attributes:
!   language: f95
!
!
!$$$

  use nemsio_module, only:  nemsio_init,nemsio_open,nemsio_close
  use nemsio_module, only:  nemsio_gfile,nemsio_getfilehead,nemsio_readrec,&
       nemsio_writerec,nemsio_readrecv,nemsio_writerecv,nemsio_getrechead
  implicit none

  type(nemsio_gfile) :: gfile_f, gfile_a, gfile_o
  character*500 filename_a,filename_f,filenameout
  integer i,n,npts,nrec,nlats,nlons,nlevs,iret
  character(16),dimension(:),allocatable:: fieldname_f,fieldname_a
  character(16),dimension(:),allocatable:: fieldlevtyp_f,fieldlevtyp_a
  integer,dimension(:),allocatable:: fieldlevel_f,fieldlevel_a,order_fa
  real,allocatable,dimension(:,:)   :: rwork_f,rwork_a,rwork_o

! read data from this file
  call getarg(1,filename_a)

! subtract data from this file
  call getarg(2,filename_f)

! and put in this file (after truncation or padding).
  call getarg(3,filenameout)

  write(6,*)'MAKEINC_NEMSIO:'
  write(6,*)'filename_f=',trim(filename_f)
  write(6,*)'filename_a=',trim(filename_a)
  write(6,*)'filenameout=',trim(filenameout)

  call nemsio_open(gfile_f,trim(filename_f),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_f)
    stop
  endif
  call nemsio_open(gfile_a,trim(filename_a),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_a)
    stop
  endif
  gfile_o=gfile_a
  call nemsio_open(gfile_o,trim(filenameout),'WRITE',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filenameout)
    stop
  endif

  call nemsio_getfilehead(gfile_f, nrec=nrec, dimx=nlons, dimy=nlats, dimz=nlevs, iret=iret)
  if (iret .ne. 0) then
    print *,'error getting header info from ',trim(filename_f)
    stop
  endif

  npts=nlons*nlats
  allocate(rwork_f(npts,nrec),rwork_a(npts,nrec),rwork_o(npts,nrec))

  allocate(fieldname_f(nrec), fieldlevtyp_f(nrec),fieldlevel_f(nrec))
  allocate(fieldname_a(nrec), fieldlevtyp_a(nrec),fieldlevel_a(nrec))
  allocate(order_fa(nrec))

  do n=1,nrec
     call nemsio_readrec(gfile_f,n,rwork_f(:,n),iret=iret) ! member analysis
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_f)
       stop
     endif
     call nemsio_getrechead(gfile_f,n,fieldname_f(n),fieldlevtyp_f(n),fieldlevel_f(n),iret=iret)
  end do
  do n=1,nrec
     call nemsio_readrec(gfile_a,n,rwork_a(:,n),iret=iret) ! member analysis
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_a)
       stop
     endif
     call nemsio_getrechead(gfile_a,n,fieldname_a(n),fieldlevtyp_a(n),fieldlevel_a(n),iret=iret)
  end do
  call getorder(fieldname_f,fieldname_a,fieldlevtyp_f,fieldlevtyp_a,fieldlevel_f,fieldlevel_f,nrec,order_fa)

  do n=1,nrec
     do i=1,npts
        rwork_o(i,n) = rwork_a(i,n) - rwork_f(i,order_fa(n))
     end do
  end do

  do n=1,nrec
     call nemsio_writerec(gfile_o,n,rwork_o(:,n),iret=iret)
     if (iret .ne. 0) then
       print *,'error writing rec ',n,trim(filenameout)
       stop
     endif
  end do

  call nemsio_close(gfile_f,iret=iret)
  call nemsio_close(gfile_a,iret=iret)
  call nemsio_close(gfile_o,iret=iret)

END program makeinc_nemsio

subroutine getorder(flnm1,flnm2,fllevtyp1,fllevtyp2,fllev1,fllev2,nrec,order)
  integer nrec
  character(16):: flnm1(nrec),flnm2(nrec),fllevtyp1(nrec),fllevtyp2(nrec)
  integer ::  fllev1(nrec),fllev2(nrec)
  integer, intent(out) ::  order(nrec)

  integer i,j

  order=0
  do i=1,nrec
     doloopj: do j=1,nrec
        if(flnm1(i)==flnm2(j).and.fllevtyp1(i)==fllevtyp2(j).and.fllev1(i)==fllev2(j)) then
           order(i)=j
           exit doloopj
        endif
     enddo doloopj
  enddo

end subroutine getorder
