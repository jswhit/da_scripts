program adjustps    
!$$$  main program documentation block
!
! program:  adjustps
!
! prgmmr: whitaker         org: esrl/psd               date: 2017-11-02
!
! abstract:  change orography in file 1 to match file 2, adjust ps
!            to new orography, write out updated file.
!
! program history log:
!   2017-11-02  Initial version.
!
! usage: adjustps.x <file_1> <file_2> <fileout> <nlevt>
! nlevt is optional - sets level index for Benjamin and Miller temperature
! that is used in pressure adjustment.
!
! attributes:
!   language: f95
!
!$$$

  use nemsio_module, only:  nemsio_init,nemsio_open,nemsio_close
  use nemsio_module, only:  nemsio_gfile,nemsio_getfilehead,nemsio_readrec,&
       nemsio_writerec,nemsio_readrecv,nemsio_writerecv,nemsio_getrechead

  implicit none

  real,parameter:: zero=0.0_4, one=1.0_4

  character*500 filename_1,filename_2,filename_o
  character*3 charnlev
  integer nflds,iret,latb,lonb,nlevs,npts,k,n,nlevt
  integer krecu,krecv,krect,krecq,krecoz,kreccwmr,nrec
  real,allocatable,dimension(:,:,:) :: vcoord
  real,allocatable,dimension(:,:) :: rwork_1,rwork_2,pressi,pressl
  real,allocatable,dimension(:) :: delz,delps,ak,bk,t0
  real tpress,tv,kap1,kapr,rd,cp,grav,rlapse,alpha,ps,preduced,zob,zmodel,rv,fv
  type(nemsio_gfile) :: gfile_1,gfile_2,gfile_o

! constants.
  grav = 9.8066
  rlapse = 0.0065
  rd = 287.05
  rv = 461.5
  fv = rv/(rd-one)
  cp = 1004.
  kap1 = (rd/cp)+1.0
  kapr = (cp/rd)
  alpha = rd*rlapse/grav

  call w3tagb('ADJUSTPS',2011,0319,0055,'NP25')

! read data from this file
  call getarg(1,filename_1)

! subtract this mean
  call getarg(2,filename_2)

! then add to this mean
  call getarg(3,filename_o)

! model level to use for Benjamin and Miller pressure adjustment
  if (iargc() > 3) then
    call getarg(4,charnlev)
    read(charnlev,'(i3)') nlevt
  else
    nlevt = 1 ! default value
  endif

  write(6,*)'ADJUSTPS:'
  write(6,*)'filename_1=',trim(filename_1)
  write(6,*)'filename_2=',trim(filename_2)
  write(6,*)'filename_o=',trim(filename_o)
  write(6,*)'nlevt=',nlevt

  call nemsio_open(gfile_1,trim(filename_1),'READ',iret=iret)
  if (iret == 0 ) then
      write(6,*)'Read nemsio ',trim(filename_1),' iret=',iret
      call nemsio_getfilehead(gfile_1, nrec=nrec, dimx=lonb, dimy=latb, dimz=nlevs, iret=iret)
      write(6,*)' lonb=',lonb,' latb=',latb,' levs=',nlevs,' nrec=',nrec
  else
      write(6,*)'***ERROR*** ',trim(filename_1),' contains unrecognized format.  ABORT'
  endif

  call nemsio_open(gfile_2,trim(filename_2),'READ',iret=iret)

  npts=lonb*latb
  nflds = 2 + 6*nlevs
  print *,'nrec,nflds',nrec,nflds
  if (nrec .ne. nflds) then
     print *,'number of records in file not what is expected, aborting..'
     stop
  endif
  allocate(rwork_1(npts,nflds))
  allocate(rwork_2(npts,2))
  allocate(delz(npts))
  allocate(delps(npts))
  allocate(t0(npts))
  allocate(pressi(npts,nlevs+1))
  allocate(pressl(npts,nlevs))
  allocate(ak(nlevs+1))
  allocate(bk(nlevs+1))
  rwork_1 = zero; rwork_2 = zero
  allocate(vcoord(nlevs+1,3,2))
  call nemsio_getfilehead(gfile_1,vcoord=vcoord,iret=iret)
  ak = vcoord(:,1,1); bk = vcoord(:,2,1)
  deallocate(vcoord)

  call nemsio_readrecv(gfile_1,'pres','sfc',1,rwork_1(:,1),iret=iret)
  call nemsio_readrecv(gfile_1,'hgt','sfc',1,rwork_1(:,2),iret=iret)
  call nemsio_readrecv(gfile_2,'pres','sfc',1,rwork_2(:,1),iret=iret)
  call nemsio_readrecv(gfile_2,'hgt','sfc',1,rwork_2(:,2),iret=iret)
  delz = rwork_1(:,2) - rwork_2(:,2)
  delps = rwork_1(:,1) - rwork_2(:,1)
  print *,'min/max delz = ',minval(delz),maxval(delz)
  print *,'min/max delps = ',minval(delps),maxval(delps)
  do k = 1,nlevs
      krecu    = 2 + 0*nlevs + k
      krecv    = 2 + 1*nlevs + k
      krect    = 2 + 2*nlevs + k
      krecq    = 2 + 3*nlevs + k
      krecoz   = 2 + 4*nlevs + k
      kreccwmr = 2 + 5*nlevs + k
      call nemsio_readrecv(gfile_1,'ugrd', 'mid layer',k,rwork_1(:,krecu),   iret=iret)
      call nemsio_readrecv(gfile_1,'vgrd', 'mid layer',k,rwork_1(:,krecv),   iret=iret)
      call nemsio_readrecv(gfile_1,'tmp',  'mid layer',k,rwork_1(:,krect),   iret=iret)
      call nemsio_readrecv(gfile_1,'spfh', 'mid layer',k,rwork_1(:,krecq),   iret=iret)
      call nemsio_readrecv(gfile_1,'o3mr', 'mid layer',k,rwork_1(:,krecoz),  iret=iret)
      call nemsio_readrecv(gfile_1,'clwmr','mid layer',k,rwork_1(:,kreccwmr),iret=iret)
  enddo
  call nemsio_close(gfile_1,iret=iret)
  !call nemsio_close(gfile_2,iret=iret)

  !==> pressure at layers and interfaces.
  do k=1,nlevs+1
     pressi(:,k)=ak(k)+bk(k)*rwork_1(:,1) 
  enddo
  do k=1,nlevs
     ! gsi formula ("phillips vertical interpolation")
     pressl(:,k)=((pressi(:,k)**kap1-pressi(:,k+1)**kap1)/&
                  (kap1*(pressi(:,k)-pressi(:,k+1))))**kapr
  end do
  deallocate(ak,bk,pressi)

  ! adjust surface pressure.
  do n=1,npts
! compute MAPS pressure reduction from model to station elevation
! See Benjamin and Miller (1990, MWR, p. 2100)
! uses 'effective' surface temperature extrapolated
! from virtual temp (tv) at pressure tpress
! using standard atmosphere lapse rate.
! ps - surface pressure to reduce.
! t - virtual temp. at pressure tpress.
! zmodel - model orographic height.
! zob - station height
     krect    = 2 + 2*nlevs + nlevt
     krecq    = 2 + 3*nlevs + nlevt
     tv = (1.+fv*rwork_1(n,krecq))*rwork_1(n,krect)
     tpress = pressl(n,nlevt); ps = rwork_1(n,1)
     zmodel = rwork_2(n,2); zob = rwork_1(n,2)
     t0(n) = tv*(ps/tpress)**alpha ! eqn 4 from B&M
     preduced = ps*((t0(n) + rlapse*(zob-zmodel))/t0(n))**(1./alpha) ! eqn 1 from B&M
     rwork_1(n,2) = rwork_2(n,2) ! new orography
     rwork_1(n,1) = preduced ! surface pressure adjusted to new orography
  enddo
  print *,'min/max effective surface t',minval(t0),maxval(t0)
  delps = rwork_1(:,1) - rwork_2(:,1)
  print *,'min/max delps after adjustment = ',minval(delps),maxval(delps)
  deallocate(delps,delz,t0,pressl,rwork_2)
  gfile_o=gfile_2
  call nemsio_open(gfile_o,trim(filename_o),'WRITE',iret=iret)
  call nemsio_writerecv(gfile_o,'pres','sfc',1,rwork_1(:,1),iret=iret)
  call nemsio_writerecv(gfile_o,'hgt','sfc',1,rwork_1(:,2),iret=iret)
  do k = 1,nlevs
      krecu    = 2 + 0*nlevs + k
      krecv    = 2 + 1*nlevs + k
      krect    = 2 + 2*nlevs + k
      krecq    = 2 + 3*nlevs + k
      krecoz   = 2 + 4*nlevs + k
      kreccwmr = 2 + 5*nlevs + k
      call nemsio_writerecv(gfile_o,'ugrd', 'mid layer',k,rwork_1(:,krecu),   iret=iret)
      call nemsio_writerecv(gfile_o,'vgrd', 'mid layer',k,rwork_1(:,krecv),   iret=iret)
      call nemsio_writerecv(gfile_o,'tmp',  'mid layer',k,rwork_1(:,krect),   iret=iret)
      call nemsio_writerecv(gfile_o,'spfh', 'mid layer',k,rwork_1(:,krecq),   iret=iret)
      call nemsio_writerecv(gfile_o,'o3mr', 'mid layer',k,rwork_1(:,krecoz),  iret=iret)
      call nemsio_writerecv(gfile_o,'clwmr','mid layer',k,rwork_1(:,kreccwmr),iret=iret)
  enddo
  deallocate(rwork_1)
  call nemsio_close(gfile_o,iret=iret)
  call nemsio_close(gfile_2,iret=iret)

  call w3tage('ADJUSTPS')

END program adjustps
