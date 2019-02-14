PROGRAM calc_increment_nemsio
!$$$  main program documentation block
!
! program:  calc_increment_nemsio
!
! prgmmr: whitaker         org: esrl/psd               date: 2019-02-23
!
! abstract:  difference two nemsio files, write out increment netcdf increment
! file for ingest into FV3.  The data in increment file must be oriented
! from south to north and from top to bottom in the vertical.
!
! program history log:
!   2019-02-12  Initial version.
!
! usage:
!   input files: filename_fg filename_anal (1st two command line args)
!
!   output files: filename_inc (3rd command line arg)

!   4th command line arg is logical for controlling whether microphysics
!   increment is computed.  5th command line argument is logical controlling
!   whether delz increment is computed hydrostatically from temp, humidity
!   and dpres.
!
! attributes:
!   language: f95
!
!
!$$$

  use nemsio_module, only:  nemsio_charkind,nemsio_init,nemsio_open,nemsio_close
  use nemsio_module, only:  nemsio_gfile,nemsio_getfilehead,nemsio_readrec,&
       nemsio_readrecv,nemsio_getrechead
  use netcdf
  implicit none

  ! these are used in computation of delz increment
  real,parameter :: rgas   = 2.8705e+2
  real,parameter :: rvap   = 4.6150e+2
  real,parameter :: grav   = 9.8066

  type(nemsio_gfile) :: gfile_anal, gfile_fg
  character*500 filename_anal,filename_inc,filename_fg
  integer i,j,k,n,npts,nrec,nlats,nlons,nlevs,iret,nrec2,nlons2,nlats2,nlevs2
  character(nemsio_charkind),dimension(:),allocatable:: fieldname_fg,fieldname_anal
  character(nemsio_charkind),dimension(:),allocatable:: fieldlevtyp_fg,fieldlevtyp_anal
  character(nemsio_charkind) :: field,ncvarname
  integer,dimension(:),allocatable:: fieldlevel_fg,fieldlevel_anal,order_anal
  real,allocatable,dimension(:) :: levs,ilevs,lons,lats,lats2,lons2
  real,allocatable,dimension(:,:)   :: rwork_fg,rwork_anal,rwork_inc,incdata2
  real,allocatable,dimension(:,:,:) :: incdata,vcoord
  real,allocatable,dimension(:,:,:) :: dpres_fg,dpres_anal,tmp_fg,tmp_anal,&
                                       spfh_fg,spfh_anal,fg_dz,anal_dz,ptop,pbot
  integer, dimension(3) :: dimid_3d
  integer, dimension(1) :: dimid_1d
  integer varid_lon,varid_lat,varid_lev,varid_ilev,varid_hyai,varid_hybi,&
          dimid_lon,dimid_lat,dimid_lev,dimid_ilev,ncfileid,ncstatus
  logical :: no_mpinc, inc_delz
  character(len=10) :: bufchar

  call getarg(1,filename_fg)    ! first guess nemsio file
  call getarg(2,filename_anal)  ! analysis nemsio file
  call getarg(3,filename_inc)   ! output increment file
  call getarg(4, bufchar)
  read(bufchar,'(L)') no_mpinc  ! if T, microsphysics increments computed
  call getarg(5, bufchar)
  read(bufchar,'(L)') inc_delz  ! if T, delz increment computed

  write(6,*)'CALC_INCREMENT_NEMSIO:'
  write(6,*)'filename_fg=',trim(filename_fg)
  write(6,*)'filename_anal=',trim(filename_anal)
  write(6,*)'filename_inc=',trim(filename_inc)
  write(6,*)'no_mpinc',no_mpinc
  write(6,*)'inc_delz',inc_delz

  call nemsio_open(gfile_fg,trim(filename_fg),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_fg)
    stop
  endif
  call nemsio_open(gfile_anal,trim(filename_anal),'READ',iret=iret)
  if (iret .ne. 0) then
    print *,'error opening ',trim(filename_anal)
    stop
  endif

  call nemsio_getfilehead(gfile_fg, nrec=nrec, dimx=nlons, dimy=nlats, dimz=nlevs, iret=iret)
  if (iret .ne. 0) then
    print *,'error getting header info from ',trim(filename_fg)
    stop
  endif
  print *,'nlons,nlats,nlevs,nrec',nlons,nlats,nlevs,nrec
  call nemsio_getfilehead(gfile_anal, nrec=nrec2, dimx=nlons2, dimy=nlats2, dimz=nlevs2, iret=iret)
  if (iret .ne. 0) then
    print *,'error getting header info from ',trim(filename_anal)
    stop
  endif
  if (nrec /= nrec2 .or. nlons /= nlons2 .or. nlats /= nlats2 .or. &
      nlevs /= nlevs2) then
    print *,'expecting nrec,nlons,nlats,nlevs =',nrec,nlons,nlats,nlevs
    print *,'got nrec,nlons,nlats,nlevs =',nrec2,nlons2,nlats2,nlevs2
    print *,'header does not match in ',trim(filename_anal)
    stop
  endif

  allocate(vcoord(nlevs+1,3,2),lons(nlons),lats(nlats),lats2(nlons*nlats),lons2(nlons*nlats))
  call nemsio_getfilehead(gfile_fg,iret=iret,vcoord=vcoord,lat=lats2,lon=lons2)
  if (iret /= 0) then
    print *, 'problem with nemsio_getfilehead getting vcoord, iret=', iret
    stop 
  endif
  n = 0
  do j=1,nlats
  do i=1,nlons
     n = n + 1
     if (i .eq. 1) lats(nlats-j+1) = lats2(n)
     if (j .eq. 1) lons(i) = lons2(n)
  enddo
  enddo
  if (lats(1) .gt. lats(nlats)) then
    print *,'error: code assumes lats in nemsio files are N to S'
    stop
  endif
  deallocate(lons2,lats2)

  npts=nlons*nlats
  allocate(rwork_anal(npts,nrec),rwork_fg(npts,nrec),rwork_inc(npts,nrec))
  allocate(fieldname_anal(nrec), fieldlevtyp_anal(nrec),fieldlevel_anal(nrec))
  allocate(fieldname_fg(nrec), fieldlevtyp_fg(nrec),fieldlevel_fg(nrec))
  allocate(order_anal(nrec),levs(nlevs),ilevs(nlevs+1))
  allocate(incdata(nlons,nlats,nlevs),incdata2(nlons,nlats))

  do n=1,nrec
     call nemsio_readrec(gfile_fg,n,rwork_fg(:,n),iret=iret) ! first guess data
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_fg)
       stop
     endif
     call nemsio_getrechead(gfile_fg,n,fieldname_fg(n),fieldlevtyp_fg(n),fieldlevel_fg(n),iret=iret)
  end do
  do n=1,nrec
     call nemsio_readrec(gfile_anal,n,rwork_anal(:,n),iret=iret) ! analysis data
     if (iret .ne. 0) then
       print *,'error reading rec ',n,trim(filename_anal)
       stop
     endif
     call nemsio_getrechead(gfile_anal,n,fieldname_anal(n),fieldlevtyp_anal(n),fieldlevel_anal(n),iret=iret)
  end do
  call getorder(fieldname_fg,fieldname_anal,fieldlevtyp_fg,fieldlevtyp_anal,fieldlevel_fg,fieldlevel_anal,nrec,order_anal)

  ! increments order as fields in first guess file.
  do n=1,nrec
     do i=1,npts
        rwork_inc(i,n) = rwork_anal(i,order_anal(n))-rwork_fg(i,n) 
     end do
  end do

  call nemsio_close(gfile_fg,iret=iret)
  call nemsio_close(gfile_anal,iret=iret)

! write out netcdf increment file.
  ncstatus = nf90_create(trim(filename_inc),           &
       cmode=ior(NF90_CLOBBER,NF90_64BIT_OFFSET),ncid=ncfileid)
  if (ncstatus /= nf90_noerr) then
     print *, 'error opening file ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_def_dim(ncfileid,'lon',nlons,dimid_lon)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating lon dim ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_def_dim(ncfileid,'lat',nlats,dimid_lat)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating lat dim ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_def_dim(ncfileid,'lev',nlevs,dimid_lev)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating lev dim ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_def_dim(ncfileid,'ilev',nlevs+1,dimid_ilev)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating ilev dim ',trim(nf90_strerror(ncstatus))
     stop
  endif
  dimid_1d(1) = dimid_lon
  ncstatus = nf90_def_var(ncfileid,'lon',nf90_float,dimid_1d,   &
       & varid_lon)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating lon ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_put_att(ncfileid,varid_lon,'units','degrees_east')
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating lon units ',trim(nf90_strerror(ncstatus))
     stop
  endif
  dimid_1d(1) = dimid_lat
  ncstatus = nf90_def_var(ncfileid,'lat',nf90_float,dimid_1d,   &
       & varid_lat)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating lat ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_put_att(ncfileid,varid_lat,'units','degrees_north')
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating lat units ',trim(nf90_strerror(ncstatus))
     stop
  endif
  dimid_1d(1) = dimid_lev
  ncstatus = nf90_def_var(ncfileid,'lev',nf90_float,dimid_1d,   &
       & varid_lev)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating lev ',trim(nf90_strerror(ncstatus))
     stop
  endif
  dimid_1d(1) = dimid_ilev
  ncstatus = nf90_def_var(ncfileid,'ilev',nf90_float,dimid_1d,  &
       & varid_ilev)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating ilev ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_def_var(ncfileid,'hyai',nf90_float,dimid_1d,  &
       & varid_hyai)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating hyai ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_def_var(ncfileid,'hybi',nf90_float,dimid_1d,  &
       & varid_hybi)
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating hybi ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_put_att(ncfileid,nf90_global,'source','GSI')
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating global attribute source',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_put_att(ncfileid,nf90_global,'comment','global analysis increment from calc_increment_nemsio')
  if (ncstatus /= nf90_noerr) then
     print *, 'error creating global attribute comment',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_enddef(ncfileid)
  if (ncstatus /= nf90_noerr) then
     print *,'enddef error ',trim(nf90_strerror(ncstatus))
     stop
  endif

  ncstatus = nf90_put_var(ncfileid,varid_lon,lons)
  if (ncstatus /= nf90_noerr) then
     print *, 'error writing lon ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_put_var(ncfileid,varid_lat,lats)
  if (ncstatus /= nf90_noerr) then
     print *, 'error writing lat ',trim(nf90_strerror(ncstatus))
     stop
  endif
  do k=1,nlevs
     levs(k)=k
  enddo
  ncstatus = nf90_put_var(ncfileid,varid_lev,levs)
  if (ncstatus /= nf90_noerr) then
     print *, 'error writing lev ',trim(nf90_strerror(ncstatus))
     stop
  endif
  do k=1,nlevs+1
     ilevs(k)=k
  enddo
  ncstatus = nf90_put_var(ncfileid,varid_ilev,ilevs)
  if (ncstatus /= nf90_noerr) then
     print *, 'error writing ilev ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ! note that levels go from top to bottom (opposite to nemsio files)
  ncstatus = nf90_put_var(ncfileid,varid_hyai,vcoord(nlevs+1:1:-1,1,1))
  if (ncstatus /= nf90_noerr) then
     print *, 'error writing hyai ',trim(nf90_strerror(ncstatus))
     stop
  endif
  ncstatus = nf90_put_var(ncfileid,varid_hybi,vcoord(nlevs+1:1:-1,2,1))
  if (ncstatus /= nf90_noerr) then
     print *, 'error writing hybi ',trim(nf90_strerror(ncstatus))
     stop
  endif

  dimid_3d(1) = dimid_lon
  dimid_3d(2) = dimid_lat
  dimid_3d(3) = dimid_lev
  
  ncvarname = 'u_inc';field = 'ugrd'
  call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.true.)
  if (minval(incdata) > 1.e30) then
     print *,trim(field),' not found'
     stop
  endif

  ncvarname = 'v_inc';field = 'vgrd'
  call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.true.)
  if (minval(incdata) > 1.e30) then
     print *,trim(field),' not found'
     stop
  endif

  ncvarname = 'T_inc';field = 'tmp'
  call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.true.)
  if (minval(incdata) > 1.e30) then
     print *,trim(field),' not found'
     stop
  endif

  ncvarname = 'delp_inc';field = 'dpres'
  call get3dfield(rwork_inc,incdata,field,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec)
  if (minval(incdata) > 1.e30) then
     print *,'inferring delp_inc from ps inc'
     ! no dpres found, infer increment from ps
     field = 'pres'
     call get2dfield(rwork_inc,incdata2,field,fieldlevel_fg,fieldname_fg,nlons,nlats,1,nrec)
     if (minval(incdata2) > 1.e30) then
        print *,'neither dpres or surface pressure found'
        stop
     endif
     do k=1,nlevs ! data goes from top to bottom
       incdata(:,:,k) = incdata2(:,:)*(vcoord(nlevs-k+1,2,1)-vcoord(nlevs-k+2,2,1))
     enddo
  endif 
  call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.false.)
  if (minval(incdata) > 1.e30) then
     print *,trim(field),' not found'
     stop
  endif

! compute hydrostatic delz increment if requested
! hydrostatic equation g*dz = -R_d*T_v*dlnp. This is untested code.
  if (inc_delz) then
    allocate(dpres_fg(nlons,nlats,nlevs),dpres_anal(nlons,nlats,nlevs))
    allocate(tmp_fg(nlons,nlats,nlevs),tmp_anal(nlons,nlats,nlevs))
    allocate(spfh_fg(nlons,nlats,nlevs),spfh_anal(nlons,nlats,nlevs))
    allocate(anal_dz(nlons,nlats,nlevs),fg_dz(nlons,nlats,nlevs))
    allocate(ptop(nlons,nlats,nlevs),pbot(nlons,nlats,nlevs))
    field = 'dpres'
    call get3dfield(rwork_fg,dpres_fg,field,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec)
    call get3dfield(rwork_anal,dpres_anal,field,fieldlevel_anal,fieldname_anal,nlons,nlats,nlevs,nrec)
    field = 'tmp'
    call get3dfield(rwork_fg,tmp_fg,field,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec)
    call get3dfield(rwork_anal,tmp_anal,field,fieldlevel_anal,fieldname_anal,nlons,nlats,nlevs,nrec)
    field = 'spfh'
    call get3dfield(rwork_fg,spfh_fg,field,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec)
    call get3dfield(rwork_anal,spfh_anal,field,fieldlevel_anal,fieldname_anal,nlons,nlats,nlevs,nrec)
    ptop(:,:,nlevs) = vcoord(nlevs+1,1,1)
    ! dpres goes from top to bottom, ptop/pbot go from bottom to top
    do k=1,nlevs-1
       ptop(:,:,nlevs-k)=ptop(:,:,nlevs-k+1)+dpres_fg(:,:,k)
       pbot(:,:,nlevs-k+1)=ptop(:,:,nlevs-k)
    enddo
    pbot(:,:,1) = ptop(:,:,1)+dpres_fg(:,:,nlevs)
    ! at this point ptop and pbot are bottom to top, all other vars are top to
    ! bottom.    Need to flip pbot,ptop here.
    fg_dz  = -rgas*tmp_fg*(1.+(rvap/rgas-1.)*spfh_fg)*(log(ptop(:,:,nlevs:1:-1))-log(pbot(:,:,nlevs:1:-1)))/grav
    do k=1,nlevs-1
       ptop(:,:,nlevs-k)=ptop(:,:,nlevs-k+1)+dpres_anal(:,:,k)
       pbot(:,:,nlevs-k+1)=ptop(:,:,nlevs-k)
    enddo
    pbot(:,:,1) = ptop(:,:,1)+dpres_anal(:,:,nlevs)
    anal_dz  = -rgas*tmp_anal*(1.+(rvap/rgas-1.)*spfh_anal)*(log(ptop(:,:,nlevs:1:-1))-log(pbot(:,:,nlevs:1:-1)))/grav
    incdata = anal_dz - fg_dz
    ncvarname = 'delz_inc'
    call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.false.)
    deallocate(dpres_fg,dpres_anal,tmp_fg,tmp_anal,spfh_fg,spfh_anal,fg_dz,anal_dz,ptop,pbot)
  endif

  ncvarname = 'sphum_inc';field = 'spfh'
  call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.true.)
  if (minval(incdata) > 1.e30) then
     print *,trim(field),' not found'
     stop
  endif

  ncvarname = 'o3mr_inc';field = 'o3mr'
  call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.true.)
  if (minval(incdata) > 1.e30) then
     print *,trim(field),' not found'
     stop
  endif

  if (.not. no_mpinc) then
     ncvarname = 'liq_wat_inc';field = 'clwmr'
     call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.true.)
     ncvarname = 'ice_wat_inc';field = 'icmr'
     call write_ncdata3d(rwork_inc,incdata,field,ncvarname,fieldlevel_fg,fieldname_fg,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,.true.)
  endif ! no_mpinc

  ncstatus = nf90_close(ncfileid)
  if (ncstatus /= nf90_noerr) then
     print *, 'error closing file:',trim(nf90_strerror(ncstatus))
     stop
  endif

  deallocate(rwork_anal,rwork_fg,rwork_inc)
  deallocate(fieldname_anal, fieldlevtyp_anal,fieldlevel_anal)
  deallocate(fieldname_fg, fieldlevtyp_fg,fieldlevel_fg)
  deallocate(order_anal,vcoord,levs,ilevs)
  deallocate(incdata,incdata2,lons,lats)

END program calc_increment_nemsio

subroutine getorder(flnm1,flnm2,fllevtyp1,fllevtyp2,fllev1,fllev2,nrec,order)
  use nemsio_module, only: nemsio_charkind
  integer nrec
  character(nemsio_charkind):: flnm1(nrec),flnm2(nrec),fllevtyp1(nrec),fllevtyp2(nrec)
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

  subroutine get3dfield(datain,incdata,field,fieldlevel,fieldname,nlons,nlats,nlevs,nrec)
    use nemsio_module, only: nemsio_charkind
    integer, intent(in) :: nlons,nlats,nlevs,nrec
    integer i,j,k,n,nn
    character(nemsio_charkind), intent(in) :: field
    character(nemsio_charkind), intent(in) :: fieldname(nrec)
    integer, intent(in) :: fieldlevel(nrec)
    real, intent(in) :: datain(nlons*nlats,nrec)
    real, intent(out) :: incdata(nlons,nlats,nlevs)
    real data2(nlons,nlats)
    incdata = 9.9e31 ! missing value
    do k=1,nlevs
       do n=1,nrec
          if (fieldlevel(n) == k .and. trim(fieldname(n)) == trim(field)) then
             nn = 0
             do j=1,nlats
             do i=1,nlons
                nn = nn + 1
                data2(i,j) = datain(nn,n)
             enddo
             enddo
             do j=1,nlats 
! flip lats (from N to S to S to N)
! flip vertical so data goes from top to bottom
                incdata(:,nlats-j+1,nlevs-k+1) = data2(:,j)
             enddo
          endif
       enddo
    enddo
  end subroutine get3dfield

  subroutine get2dfield(datain,incdata,field,fieldlevel,fieldname,nlons,nlats,nlev,nrec)
    use nemsio_module, only: nemsio_charkind
    integer, intent(in) :: nlev,nlons,nlats,nrec
    integer i,j,n,nn
    character(nemsio_charkind), intent(in) :: field
    character(nemsio_charkind), intent(in) :: fieldname(nrec)
    integer, intent(in) :: fieldlevel(nrec)
    real, intent(in) :: datain(nlons*nlats,nrec)
    real, intent(out) :: incdata(nlons,nlats)
    real data2(nlons,nlats)
    incdata = 9.9e31 ! missing value
    do n=1,nrec
       if (fieldlevel(n) == nlev .and. trim(fieldname(n)) == trim(field)) then
          nn = 0
          do j=1,nlats
          do i=1,nlons
             nn = nn + 1
             data2(i,j) = datain(nn,n)
          enddo
          enddo
          do j=1,nlats ! flip lats
             incdata(:,nlats-j+1) = data2(:,j)
          enddo
       endif
    enddo
  end subroutine get2dfield

  subroutine write_ncdata3d(rwork_inc,incdata,field,ncvarname,&
  fieldlevel,fieldname,nlons,nlats,nlevs,nrec,ncfileid,dimid_3d,getincdata)
  use nemsio_module, only: nemsio_charkind
  use netcdf
  integer, intent(in) :: nlons,nlats,nlevs,nrec,ncfileid,dimid_3d(3)
  integer varid,ncstatus
  real, intent(inout) ::  incdata(nlons,nlats,nlevs)
  real, intent(in) :: rwork_inc(nlons*nlats,nrec)
  character(nemsio_charkind), intent(in) :: field,ncvarname
  character(nemsio_charkind), intent(in) :: fieldname(nrec)
  integer, intent(in) :: fieldlevel(nrec)
  logical, intent(in) :: getincdata
  if (getincdata) then
     call get3dfield(rwork_inc,incdata,field,fieldlevel,fieldname,nlons,nlats,nlevs,nrec)
  endif
  if (minval(incdata) < 1.e30) then
     ncstatus = nf90_redef(ncfileid)
     if (ncstatus /= nf90_noerr) then
        print *,'redef error ',trim(nf90_strerror(ncstatus))
        stop
     endif
     ncstatus = nf90_def_var(ncfileid,trim(ncvarname),nf90_float,dimid_3d,varid)
     if (ncstatus /= nf90_noerr) then
        print *, 'error creating',trim(ncvarname),' ',trim(nf90_strerror(ncstatus))
        stop
     endif
     ncstatus = nf90_enddef(ncfileid)
     if (ncstatus /= nf90_noerr) then
        print *,'enddef error ',trim(nf90_strerror(ncstatus))
        stop
     endif
     print *,'writing ',trim(ncvarname),' min/max =',minval(incdata),maxval(incdata)
     ncstatus = nf90_put_var(ncfileid,varid,incdata)
     if (ncstatus /= nf90_noerr) then
        print *, trim(nf90_strerror(ncstatus))
        stop
     endif
   endif
   end subroutine write_ncdata3d
