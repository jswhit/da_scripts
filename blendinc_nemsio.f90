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

  type(nemsio_gfile) :: gfile_inc1, gfile_inc2, gfile_o, gfile_i
  character*500 filename_inc2,filename_inc1,filenameout,filenamein
  character(len=4) charnin
  integer i,n,npts,nrec,nlats,nlons,nlevs,iret,ialpha,ibeta
  character(16),dimension(:),allocatable:: fieldname_i,fieldname_inc1,fieldname_inc2
  character(16),dimension(:),allocatable:: fieldlevtyp_i,fieldlevtyp_inc1,fieldlevtyp_inc2
  integer,dimension(:),allocatable:: fieldlevel_i,fieldlevel_inc1,fieldlevel_inc2,order_inc2,order_inc1
  real,allocatable,dimension(:,:)   :: rwork_i,rwork_inc1,rwork_inc2,rwork_o
  real alpha,beta

  call getarg(1,filenamein)
  call getarg(2,filename_inc1)
  call getarg(3,filename_inc2)
  call getarg(4,filenameout)
! blending coefficients
  call getarg(5,charnin)
  read(charnin,'(i4)') ialpha
  alpha = ialpha/1000.
  call getarg(6,charnin)
  read(charnin,'(i4)') ibeta
  beta = ibeta/1000.

  write(6,*)'BLENDINC_NEMSIO:'
  write(6,*)'filenamein=',trim(filenamein)
  write(6,*)'filename_inc1=',trim(filename_inc1)
  write(6,*)'filename_inc2=',trim(filename_inc2)
  write(6,*)'filenameout=',trim(filenameout)
  write(6,*)'alpha,beta = ',alpha,beta

  call nemsio_open(gfile_i,trim(filenamein),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filenamein)
    stop
  endif
  call nemsio_open(gfile_inc1,trim(filename_inc1),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_inc1)
    stop
  endif
  call nemsio_open(gfile_inc2,trim(filename_inc2),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_inc2)
    stop
  endif
  gfile_o=gfile_inc2 ! use header for enkf increment
  call nemsio_open(gfile_o,trim(filenameout),'WRITE',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filenameout)
    stop
  endif

  call nemsio_getfilehead(gfile_i, nrec=nrec, dimx=nlons, dimy=nlats, dimz=nlevs, iret=iret)
  if (iret .ne. 0) then
    print *,'error getting header info from ',trim(filenamein)
    stop
  endif

  npts=nlons*nlats
  allocate(rwork_inc1(npts,nrec),rwork_inc2(npts,nrec),rwork_i(npts,nrec),rwork_o(npts,nrec))

  allocate(fieldname_inc1(nrec), fieldlevtyp_inc1(nrec),fieldlevel_inc1(nrec))
  allocate(fieldname_inc2(nrec), fieldlevtyp_inc2(nrec),fieldlevel_inc2(nrec))
  allocate(fieldname_i(nrec), fieldlevtyp_i(nrec),fieldlevel_i(nrec))
  allocate(order_inc1(nrec))
  allocate(order_inc2(nrec))

  do n=1,nrec
     call nemsio_readrec(gfile_i,n,rwork_i(:,n),iret=iret) ! member analysis
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filenamein)
       stop
     endif
     call nemsio_getrechead(gfile_i,n,fieldname_i(n),fieldlevtyp_i(n),fieldlevel_i(n),iret=iret)
  end do
  do n=1,nrec
     call nemsio_readrec(gfile_inc1,n,rwork_inc1(:,n),iret=iret) ! member analysis
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_inc1)
       stop
     endif
     call nemsio_getrechead(gfile_inc1,n,fieldname_inc1(n),fieldlevtyp_inc1(n),fieldlevel_inc1(n),iret=iret)
  end do
  do n=1,nrec
     call nemsio_readrec(gfile_inc2,n,rwork_inc2(:,n),iret=iret) ! member analysis
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_inc2)
       stop
     endif
     call nemsio_getrechead(gfile_inc2,n,fieldname_inc2(n),fieldlevtyp_inc2(n),fieldlevel_inc2(n),iret=iret)
  end do
  call getorder(fieldname_i,fieldname_inc1,fieldlevtyp_i,fieldlevtyp_inc1,fieldlevel_i,fieldlevel_inc1,nrec,order_inc1)
  call getorder(fieldname_i,fieldname_inc2,fieldlevtyp_i,fieldlevtyp_inc2,fieldlevel_i,fieldlevel_inc2,nrec,order_inc2)

  do n=1,nrec
!  print *,n,order_inc1(n),order_inc2(n),minval(rwork_inc1(:,order_inc1(n))),&
!  maxval(rwork_inc1(:,order_inc1(n))),minval(rwork_inc2(:,order_inc2(n))),&
!  maxval(rwork_inc2(:,order_inc2(n)))
     do i=1,npts
        rwork_o(i,n) = rwork_i(i,n) + &
                       alpha*rwork_inc1(i,order_inc1(n)) + &
                       beta*rwork_inc2(i,order_inc2(n))
     end do
  end do

  do n=1,nrec
     call nemsio_writerec(gfile_o,n,rwork_o(:,n),iret=iret)
     if (iret .ne. 0) then
       print *,'error writing rec ',n,trim(filenameout)
       stop
     endif
  end do

  call nemsio_close(gfile_i,iret=iret)
  call nemsio_close(gfile_inc1,iret=iret)
  call nemsio_close(gfile_inc2,iret=iret)
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
