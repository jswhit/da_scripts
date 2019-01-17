program blendinc_nemsio
!$$$  main program documentation block
!
! program:  blendinc_nemsio
!
! prgmmr: whitaker         org: esrl/psd               date: 2009-02-23
!
! abstract:  blend increments, add to first guess
!
! program history log:
!   2009-02-23  Initial version.
!
! usage:
!   input files: filename_fg filename_anal1 filename_anal2
!                (1st 3d command line args)
!
!   output files: $filename_anal (4th command line arg)
!
!   input parameters:  ialpha, ibeta (5th and 6th command line arg)
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

  type(nemsio_gfile) :: gfile_anal1, gfile_anal2, gfile_anal, gfile_fg
  character*500 filename_anal2,filename_anal1,filename_anal,filename_fg
  character(len=4) charnin
  integer i,n,npts,nrec,nlats,nlons,nlevs,iret,ialpha,ibeta
  character(16),dimension(:),allocatable:: fieldname_fg,fieldname_anal1,fieldname_anal2
  character(16),dimension(:),allocatable:: fieldlevtyp_fg,fieldlevtyp_anal1,fieldlevtyp_anal2
  integer,dimension(:),allocatable:: fieldlevel_fg,fieldlevel_anal1,fieldlevel_anal2,order_anal2,order_anal1
  real,allocatable,dimension(:,:)   :: rwork_fg,rwork_anal1,rwork_anal2,rwork_anal
  real alpha,beta

  call getarg(1,filename_fg)    ! first guess nemsio file
  call getarg(2,filename_anal1) ! 3dvar analysis
  call getarg(3,filename_anal2) ! enkf analysis
  call getarg(4,filename_anal)  ! blended analysis
! blending coefficients
  call getarg(5,charnin)
  read(charnin,'(i4)') ialpha ! wt for anal1 (3dvar)
  alpha = ialpha/1000.
  call getarg(6,charnin)
  read(charnin,'(i4)') ibeta ! wt for anal2 (enkf)
  beta = ibeta/1000.
! new_anal = fg + alpha*(anal1-fg) + beta(anal2-fg)
!          = (1.-alpha-beta)*fg + alpha*anal1 + beta*anal2

  write(6,*)'BLENDINC_NEMSIO:'
  write(6,*)'filename_fg=',trim(filename_fg)
  write(6,*)'filename_anal1=',trim(filename_anal1)
  write(6,*)'filename_anal2=',trim(filename_anal2)
  write(6,*)'filename_anal=',trim(filename_anal)
  write(6,*)'alpha,beta = ',alpha,beta

  call nemsio_open(gfile_fg,trim(filename_fg),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_fg)
    stop
  endif
  call nemsio_open(gfile_anal1,trim(filename_anal1),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_anal1)
    stop
  endif
  call nemsio_open(gfile_anal2,trim(filename_anal2),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_anal2)
    stop
  endif
  gfile_anal=gfile_anal2 ! use header for enkf increment
  call nemsio_open(gfile_anal,trim(filename_anal),'WRITE',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_anal)
    stop
  endif

  call nemsio_getfilehead(gfile_fg, nrec=nrec, dimx=nlons, dimy=nlats, dimz=nlevs, iret=iret)
  if (iret .ne. 0) then
    print *,'error getting header info from ',trim(filename_fg)
    stop
  endif

  npts=nlons*nlats
  allocate(rwork_anal1(npts,nrec),rwork_anal2(npts,nrec),rwork_fg(npts,nrec),rwork_anal(npts,nrec))

  allocate(fieldname_anal1(nrec), fieldlevtyp_anal1(nrec),fieldlevel_anal1(nrec))
  allocate(fieldname_anal2(nrec), fieldlevtyp_anal2(nrec),fieldlevel_anal2(nrec))
  allocate(fieldname_fg(nrec), fieldlevtyp_fg(nrec),fieldlevel_fg(nrec))
  allocate(order_anal1(nrec))
  allocate(order_anal2(nrec))

  do n=1,nrec
     call nemsio_readrec(gfile_fg,n,rwork_fg(:,n),iret=iret) ! member analysis
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_fg)
       stop
     endif
     call nemsio_getrechead(gfile_fg,n,fieldname_fg(n),fieldlevtyp_fg(n),fieldlevel_fg(n),iret=iret)
  end do
  do n=1,nrec
     call nemsio_readrec(gfile_anal1,n,rwork_anal1(:,n),iret=iret) ! member analysis
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_anal1)
       stop
     endif
     call nemsio_getrechead(gfile_anal1,n,fieldname_anal1(n),fieldlevtyp_anal1(n),fieldlevel_anal1(n),iret=iret)
  end do
  do n=1,nrec
     call nemsio_readrec(gfile_anal2,n,rwork_anal2(:,n),iret=iret) ! member analysis
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_anal2)
       stop
     endif
     call nemsio_getrechead(gfile_anal2,n,fieldname_anal2(n),fieldlevtyp_anal2(n),fieldlevel_anal2(n),iret=iret)
  end do
  call getorder(fieldname_fg,fieldname_anal1,fieldlevtyp_fg,fieldlevtyp_anal1,fieldlevel_fg,fieldlevel_anal1,nrec,order_anal1)
  call getorder(fieldname_fg,fieldname_anal2,fieldlevtyp_fg,fieldlevtyp_anal2,fieldlevel_fg,fieldlevel_anal2,nrec,order_anal2)

  do n=1,nrec
!  print *,n,order_anal1(n),order_anal2(n),minval(rwork_anal1(:,order_anal1(n))),&
!  maxval(rwork_anal1(:,order_anal1(n))),minval(rwork_anal2(:,order_anal2(n))),&
!  maxval(rwork_anal2(:,order_anal2(n)))
     do i=1,npts
        rwork_anal(i,n) = (1.-alpha-beta)*rwork_fg(i,n) + &
                       alpha*rwork_anal1(i,order_anal1(n)) + &
                       beta*rwork_anal2(i,order_anal2(n))
     end do
  end do

  do n=1,nrec
     call nemsio_writerec(gfile_anal,n,rwork_anal(:,n),iret=iret)
     if (iret .ne. 0) then
       print *,'error writing rec ',n,trim(filename_anal)
       stop
     endif
  end do

  call nemsio_close(gfile_fg,iret=iret)
  call nemsio_close(gfile_anal1,iret=iret)
  call nemsio_close(gfile_anal2,iret=iret)
  call nemsio_close(gfile_anal,iret=iret)

END program blendinc_nemsio

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
