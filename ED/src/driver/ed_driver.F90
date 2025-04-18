!==========================================================================================!
!==========================================================================================!
!     Main subroutine that initialises the several structures for the Ecosystem Demography !
! Model 2.  In this version 2.1 all nodes solve some polygons, including the node formerly !
! known as master.                                                                         !
!------------------------------------------------------------------------------------------!
subroutine ed_driver()
   use update_derived_utils , only : update_derived_props          ! ! subroutine
   use lsm_hyd              , only : initHydrology                 ! ! subroutine
   use ed_met_driver        , only : init_met_drivers              & ! subroutine
                                   , read_met_drivers_init         & ! subroutine
                                   , update_met_drivers            ! ! subroutine
   use ed_init_history      , only : resume_from_history           ! ! subroutine
   use ed_init              , only : set_polygon_coordinates       & ! subroutine
                                   , sfcdata_ed                    & ! subroutine
                                   , load_ecosystem_state          & ! subroutine
                                   , read_obstime                  ! ! subroutine
   use grid_coms            , only : ngrids                        & ! intent(in)
                                   , time                          & ! intent(inout)
                                   , timmax                        ! ! intent(inout)
   use ed_state_vars        , only : allocate_edglobals            & ! sub-routine
                                   , filltab_alltypes              & ! sub-routine
                                   , edgrid_g                      ! ! intent(inout)
   use ed_misc_coms         , only : dtlsm                         & ! intent(in)
                                   , runtype                       & ! intent(in)
                                   , current_time                  & ! intent(in)
                                   , isoutput                      & ! intent(in)
                                   , iooutput                      & ! intent(in)
                                   , fmtrest                       & ! intent(in)
                                   , restore_file                  ! ! intent(in)
   use soil_coms            , only : alloc_soilgrid                ! ! sub-routine
   use ed_node_coms         , only : mynum                         & ! intent(in)
                                   , nnodetot                      & ! intent(in)
                                   , sendnum                       ! ! intent(in)
#if defined(RAMS_MPI)
   use mpi
   use ed_node_coms         , only : recvnum                       ! ! intent(in)
#endif
   use detailed_coms        , only : idetailed                     & ! intent(in)
                                   , patch_keep                    ! ! intent(in)
   use phenology_aux        , only : first_phenology               ! ! subroutine
   use hrzshade_utils       , only : init_cci_variables            ! ! subroutine
   use canopy_radiation_coms, only : ihrzrad                       ! ! intent(in)
   use random_utils         , only : init_random_seed              ! ! subroutine
   use budget_utils         , only : ed_init_budget                ! ! subroutine
   implicit none
   !----- Local variables. ----------------------------------------------------------------!
   character(len=12)           :: c0
   character(len=12)           :: c1
   integer                     :: ifm
   integer                     :: ping
   real                        :: t1
   real                        :: w1
   real                        :: w2
   real                        :: wtime_start
   logical                     :: patch_detailed
   !----- Local variable (MPI only). ------------------------------------------------------!
#if defined(RAMS_MPI)
   integer                     :: ierr
#endif
   !----- External functions. -------------------------------------------------------------!
   real             , external :: walltime    ! wall time
   !---------------------------------------------------------------------------------------!

   ping = 741776

   !---------------------------------------------------------------------------------------!
   !      Set the initial time.                                                            !
   !---------------------------------------------------------------------------------------!
   wtime_start = walltime(0.)
   w1          = walltime(wtime_start)
   !---------------------------------------------------------------------------------------!


   !---------------------------------------------------------------------------------------!
   !     Initialise random seed -- the MPI barrier may be unnecessary, added because the   !
   ! jobs may the the system random number generator.                                      !
   !---------------------------------------------------------------------------------------!
#if defined(RAMS_MPI)
   if (mynum /= 1) then
      call MPI_RECV(ping,1,MPI_INTEGER,recvnum,79,MPI_COMM_WORLD,MPI_STATUS_IGNORE,ierr)
   else
      write (unit=*,fmt='(a)') ' [+] Init_random_seed...'
   end if
#else
      write (unit=*,fmt='(a)') ' [+] Init_random_seed...'
#endif
   call init_random_seed()

#if defined(RAMS_MPI)
   if (mynum < nnodetot ) call MPI_Send(ping,1,MPI_INTEGER,sendnum,79,MPI_COMM_WORLD,ierr)
   if (nnodetot /= 1    ) call MPI_Barrier(MPI_COMM_WORLD,ierr)
#endif
   !---------------------------------------------------------------------------------------!


   !---------------------------------------------------------------------------------------!
   !      Set most ED model parameters that do not come from the namelist (ED2IN).         !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Load_Ed_Ecosystem_Params...'
   call load_ed_ecosystem_params()
   !---------------------------------------------------------------------------------------!




   !---------------------------------------------------------------------------------------!
   !      Overwrite the parameters in case a XML file is provided                          !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot-1) sendnum = 0

#if defined(RAMS_MPI)
   if (mynum /= 1) then
      call MPI_RECV(ping,1,MPI_INTEGER,recvnum,80,MPI_COMM_WORLD,MPI_STATUS_IGNORE,ierr)
   else
      write (unit=*,fmt='(a)') ' [+] Checking for XML config...'
   end if
#else
   write (unit=*,fmt='(a)') ' [+] Checking for XML config...'
#endif

   call overwrite_with_xml_config(mynum)

#if defined(RAMS_MPI)
   if (mynum < nnodetot ) call MPI_Send(ping,1,MPI_INTEGER,sendnum,80,MPI_COMM_WORLD,ierr)
   if (nnodetot /= 1 )    call MPI_Barrier(MPI_COMM_WORLD,ierr)
#endif
   !---------------------------------------------------------------------------------------!



   !---------------------------------------------------------------------------------------!
   !      Initialise any variable that should be initialised after the xml parameters have !
   ! been read.                                                                            !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Init_derived_params_after_xml...'
   call init_derived_params_after_xml()
   !---------------------------------------------------------------------------------------!

   !-----Always write out a copy of model parameters in xml--------------------------!
   if (mynum == nnodetot) then 
       write (unit=*,fmt='(a)') ' [+] Write parameters to xml...'      
       call write_ed_xml_config()
   endif
   !---------------------------------------------------------------------------------!



   !---------------------------------------------------------------------------------------!
   !      In case this simulation will use horizontal shading, initialise the landscape    !
   ! arrays.                                                                               !
   !---------------------------------------------------------------------------------------!
   select case (ihrzrad)
   case (0)
      continue
   case default
      if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Init_cci_variables...'
      call init_cci_variables()
   end select
   !---------------------------------------------------------------------------------------!



   !---------------------------------------------------------------------------------------!
   !      Set some polygon-level basic information, such as lon/lat/soil texture.          !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Set_Polygon_Coordinates...'
   call set_polygon_coordinates()
   !---------------------------------------------------------------------------------------!



   !---------------------------------------------------------------------------------------!
   !      Decide whether to initialise ED2 or resume from history files.  Note that the    !
   ! order of operations will depend upon the run type.  If we resume from HISTORY, we     !
   ! must read the history first then allocate soil data (as they will be read from the    !
   ! history file itself).  Otherwise, we allocate and initialise soils, then read/assign  !
   ! the initial conditions.                                                               !
   !---------------------------------------------------------------------------------------!
   select case (trim(runtype))
   case ('HISTORY')
      !------------------------------------------------------------------------------------!
      !      Initialize the model state as a replicate image of a previous  state.         !
      !------------------------------------------------------------------------------------!
      if (mynum == nnodetot-1) sendnum = 0

#if defined(RAMS_MPI)
      if (mynum /= 1) then
         call MPI_RECV(ping,1,MPI_INTEGER,recvnum,81,MPI_COMM_WORLD,MPI_STATUS_IGNORE,ierr)
      else
         write (unit=*,fmt='(a)') ' [+] Resume_From_History...'
      end if
#else
      write (unit=*,fmt='(a)') ' [+] Resume_From_History...'
#endif
      call resume_from_history()

#if defined(RAMS_MPI)
      if (mynum < nnodetot ) then
         call MPI_Send(ping,1,MPI_INTEGER,sendnum,81,MPI_COMM_WORLD,ierr)
      end if

      if (nnodetot /= 1 ) call MPI_Barrier(MPI_COMM_WORLD,ierr)
#endif
      !------------------------------------------------------------------------------------!


   case default
      !------------------------------------------------------------------------------------!
      !      Allocate soil grid arrays.                                                    !
      !------------------------------------------------------------------------------------!
      if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Alloc_Soilgrid...'
      call alloc_soilgrid()
      !------------------------------------------------------------------------------------!



      !------------------------------------------------------------------------------------!
      !      Initialise variables that are related to soil layers.                         !
      !------------------------------------------------------------------------------------!
      if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Sfcdata_ED...'
      call sfcdata_ed()
      !------------------------------------------------------------------------------------!



      !------------------------------------------------------------------------------------!
      !      Initialize state properties of polygons/sites/patches/cohorts.                !
      !------------------------------------------------------------------------------------!
      if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Load_Ecosystem_State...'
      call load_ecosystem_state()
      !------------------------------------------------------------------------------------!
   end select
   !---------------------------------------------------------------------------------------!


   !---------------------------------------------------------------------------------------!
   !      In case the runs is going to produce detailed output, we eliminate all patches   !
   ! but the one to be analysed in detail.  Special cases:                                 !
   !  0 -- Keep all patches.                                                               !
   ! -1 -- Keep the one with the highest LAI                                               !
   ! -2 -- Keep the one with the lowest LAI                                                !
   !---------------------------------------------------------------------------------------!
   patch_detailed = ibclr(idetailed,5) > 0
!   if (patch_detailed) then
      call exterminate_patches_except(patch_keep)
!   end if
   !---------------------------------------------------------------------------------------!


   !---------------------------------------------------------------------------------------!
   !      Initialize meteorological drivers.                                               !
   !---------------------------------------------------------------------------------------!
#if defined(RAMS_MPI)
   if (nnodetot /= 1) call MPI_Barrier(MPI_COMM_WORLD,ierr)
#endif
   if (mynum == nnodetot-1) sendnum = 0

#if defined(RAMS_MPI)
   if (mynum /= 1) then
      call MPI_RECV(ping,1,MPI_INTEGER,recvnum,82,MPI_COMM_WORLD,MPI_STATUS_IGNORE,ierr)
   else
      write (unit=*,fmt='(a)') ' [+] Init_Met_Drivers...'
   end if
#else
   write (unit=*,fmt='(a)') ' [+] Init_Met_Drivers...'
#endif

   call init_met_drivers()
   if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Read_Met_Drivers_Init...'
   call read_met_drivers_init()


#if defined(RAMS_MPI)
   if (mynum < nnodetot ) call MPI_Send(ping,1,MPI_INTEGER,sendnum,82,MPI_COMM_WORLD,ierr)
   if (nnodetot /= 1 ) call MPI_Barrier(MPI_COMM_WORLD,ierr)
#endif
   !---------------------------------------------------------------------------------------!



   !---------------------------------------------------------------------------------------!
   !      Initialise the site-level meteorological forcing.                                !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Update_met_drivers...'
   do ifm=1,ngrids
      call update_met_drivers(edgrid_g(ifm))
   end do
   !---------------------------------------------------------------------------------------!


   !---------------------------------------------------------------------------------------!
   !      Initialize ed fields that depend on the atmosphere.                              !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Ed_Init_Atm...'
   call ed_init_atm()
   !---------------------------------------------------------------------------------------!

   !---------------------------------------------------------------------------------------!
   !      Initialize hydrology related variables.                                          !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] initHydrology...'
   call initHydrology()
   !---------------------------------------------------------------------------------------!


   !---------------------------------------------------------------------------------------!
   !    Bypass the initialisation of derived variables and phenology when initialising ED2 !
   ! from HISTORY.                                                                         !
   !---------------------------------------------------------------------------------------!
   select case (trim(runtype))
   case ('HISTORY')
      !---- Do nothing. -------------------------------------------------------------------!
      continue
      !------------------------------------------------------------------------------------!
   case default
      !---- Initialise some derived variables. --------------------------------------------!
      do ifm=1,ngrids
         call update_derived_props(edgrid_g(ifm))
      end do
      !------------------------------------------------------------------------------------!



      !---- Initialise drought phenology. -------------------------------------------------!
      do ifm=1,ngrids
         call first_phenology(edgrid_g(ifm))
      end do
      !------------------------------------------------------------------------------------!
   end select
   !---------------------------------------------------------------------------------------!



   !---------------------------------------------------------------------------------------!
   !      Fill the variable data-tables with all of the state data.  Also calculate the    !
   ! indexing of the vectors to allow for segmented I/O of hyperslabs and referencing of   !
   ! high level hierarchical data types with their parent types.                           !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot) write (unit=*,fmt='(a)') ' [+] Filltab_Alltypes...'
   call filltab_alltypes
   !---------------------------------------------------------------------------------------!



   !---------------------------------------------------------------------------------------!
   !      Check how the output was configured and determine the averaging frequency.       !
   !---------------------------------------------------------------------------------------!
   if (mynum == nnodetot) write(unit=*,fmt='(a)') ' [+] Find frqsum...'
   call find_frqsum()
   !---------------------------------------------------------------------------------------!


   !---------------------------------------------------------------------------------------!
   !      Read obsevation time list if IOOUTPUT is set as non-zero.                        !
   !                                                                                       !
   ! MLO --- Whenever reading ASCII files, it is a good idea to apply MPI barriers, to     !
   !         avoid two nodes accessing the file at the same time (some file systems do not !
   !         like that).                                                                   !
   !---------------------------------------------------------------------------------------!
   if (iooutput /= 0) then
#if defined(RAMS_MPI)
        if (mynum /= 1) call MPI_Recv(ping,1,MPI_INTEGER,recvnum,62,MPI_COMM_WORLD         &
                                     ,MPI_STATUS_IGNORE,ierr)
#endif
        if (mynum == nnodetot) write(unit=*,fmt='(a)') ' [+] Load obstime_list...'
        call read_obstime()
#if defined(RAMS_MPI)
        if (mynum < nnodetot ) call MPI_Send(ping,1,MPI_INTEGER,sendnum,62,MPI_COMM_WORLD  &
                                            ,ierr)
#endif
    end if
   !---------------------------------------------------------------------------------------!



   !---------------------------------------------------------------------------------------!
   ! STEP 14. Run the model or skip if it is a zero time run.  In case this is a zero time !
   !          run, write the history file and the flag for restoring the run (this can     !
   !          be useful for model initialisation with large number of patches in the input !
   !          file.  In this case, one may need to request substantially more memory for   !
   !          initialisation (but a single CPU as initialisation does not benefit from     !
   !          shared-memory parallel processing), then runs can be re-submitted with less  !
   !          memory demand but more CPUs, hence reducing impacts on fairshare scores.     !
   !---------------------------------------------------------------------------------------!
   if (time < timmax) then
      !------------------------------------------------------------------------------------!
      !      Get the CPU time and print the banner.                                        !
      !------------------------------------------------------------------------------------!
      call timing(1,t1)
      w2 = walltime(wtime_start)
      if (mynum == nnodetot) then
         write(c0,'(f12.2)') t1
         write(c1,'(f12.2)') w2-w1
         write(unit=*,fmt='(/,a,/)') ' === Finish initialization; CPU(sec)='//             &
                                   trim(adjustl(c0))//'; Wall(sec)='//trim(adjustl(c1))//  &
                                   '; Time integration starts (ed_model) ==='
      end if
      !------------------------------------------------------------------------------------!



      !----- Call the time step driver. ---------------------------------------------------!
      call ed_model()
      !------------------------------------------------------------------------------------!
   else if ((timmax < dtlsm) .and. (isoutput /= 0)) then
      !----- Write the zero-time output only if the run type is 'INITIAL'. ----------------!
      select case (trim(runtype))
      case ('INITIAL')

         !---------------------------------------------------------------------------------!
         !     We must reset all budget fluxes and set all budget stocks before writing    !
         ! the history file.  This is needed because when we resume ED2 runs from history  !
         ! files, all budget variables are read from history instead of being initialised. !
         !---------------------------------------------------------------------------------!
         if (mynum == nnodetot) write(unit=*,fmt='(a)') ' [+] ED_Init_Budget.'
         do ifm=1,ngrids
            call ed_init_budget(edgrid_g(ifm),.true.)
          end do
         !---------------------------------------------------------------------------------!


         !----- Write the output file. ----------------------------------------------------!
         call h5_output('HIST')
         !---------------------------------------------------------------------------------!


         !---------------------------------------------------------------------------------!
         !     Write a file with the current history time.                                 !
         !---------------------------------------------------------------------------------!
         if (mynum == nnodetot) then
            open (unit=18,file=trim(restore_file),form='formatted',status='replace'        &
                 ,action='write')
            write(unit=18,fmt=fmtrest) current_time%year,current_time%month                &
                                      ,current_time%date,current_time%hour                 &
                                      ,current_time%min
            close(unit=18,status='keep')
         end if
         !------------------------------------------------------------------------------------!
      end select
      !------------------------------------------------------------------------------------!



      !------------------------------------------------------------------------------------!
      !      Get the CPU time and print the banner.                                        !
      !------------------------------------------------------------------------------------!
      call timing(1,t1)
      w2 = walltime(wtime_start)
      if (mynum == nnodetot) then
         write(c0,'(f12.2)') t1
         write(c1,'(f12.2)') w2-w1
         write(unit=*,fmt='(/,a,/)') ' === Finish initialization; CPU(sec)='//             &
                                   trim(adjustl(c0))//'; Wall(sec)='//trim(adjustl(c1))//  &
                                   ' ==='
      end if
      !------------------------------------------------------------------------------------!
   end if
   !---------------------------------------------------------------------------------------!

   return
end subroutine ed_driver
!==========================================================================================!
!==========================================================================================!






!==========================================================================================!
!==========================================================================================!
!     This sub-routine finds which frequency the model should use to normalise averaged    !
! variables.  FRQSUM should never exceed one day to avoid build up and overflows.          !
!------------------------------------------------------------------------------------------!
subroutine find_frqsum()
   use ed_misc_coms, only : unitfast        & ! intent(in)
                          , unitstate       & ! intent(in)
                          , isoutput        & ! intent(in)
                          , ifoutput        & ! intent(in)
                          , itoutput        & ! intent(in)
                          , imoutput        & ! intent(in)
                          , iooutput        & ! intent(in)
                          , idoutput        & ! intent(in)
                          , iqoutput        & ! intent(in)
                          , frqstate        & ! intent(in)
                          , frqfast         & ! intent(in)
                          , dtlsm           & ! intent(in)
                          , radfrq          & ! intent(in)
                          , frqsum          & ! intent(out)
                          , frqsumi         & ! intent(out)
                          , dtlsm_o_frqsum  & ! intent(out)
                          , radfrq_o_frqsum ! ! intent(out)
   use consts_coms, only: day_sec

   implicit none 
   !----- Local variables. ----------------------------------------------------------------!
   logical :: fast_output
   logical :: no_fast_output
   !---------------------------------------------------------------------------------------!


   !----- Ancillary logical tests. --------------------------------------------------------!
   fast_output     = ifoutput /= 0 .or. itoutput /= 0 .or. iooutput /= 0
   no_fast_output = .not. fast_output
   !---------------------------------------------------------------------------------------!



   if ( no_fast_output .and. isoutput == 0 .and. idoutput == 0 .and. imoutput == 0 .and.   &
        iqoutput == 0  ) then
      write(unit=*,fmt='(a)') '---------------------------------------------------------'
      write(unit=*,fmt='(a)') '  WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! '
      write(unit=*,fmt='(a)') '  WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! '
      write(unit=*,fmt='(a)') '  WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! '
      write(unit=*,fmt='(a)') '  WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! '
      write(unit=*,fmt='(a)') '  WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! '
      write(unit=*,fmt='(a)') '  WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! '
      write(unit=*,fmt='(a)') '---------------------------------------------------------'
      write(unit=*,fmt='(a)') ' You are running a simulation that will have no output...'
      frqsum=day_sec ! This avoids the number to get incredibly large.

   !---------------------------------------------------------------------------------------!
   !    Mean diurnal cycle is on.  Frqfast will be in seconds, so it is likely to be the   !
   ! smallest.  The only exception is if frqstate is more frequent thant frqfast, so we    !
   ! just need to check that too.                                                          !
   !---------------------------------------------------------------------------------------!
   elseif (iqoutput > 0) then
      if (unitstate == 0) then
         frqsum = min(min(frqstate,frqfast),day_sec)
      else
         frqsum = min(frqfast,day_sec)
      end if

   !---------------------------------------------------------------------------------------!
   !     Either no instantaneous output was requested, or the user is outputting it at     !
   ! monthly or yearly scale, force it to be one day.                                      !
   !---------------------------------------------------------------------------------------!
   elseif ((isoutput == 0  .and. no_fast_output) .or.                                      &
           (no_fast_output .and. isoutput  > 0 .and. unitstate > 1) .or.                   &
           (isoutput == 0 .and. fast_output .and. unitfast  > 1) .or.                      &
           (isoutput > 0 .and. unitstate > 1 .and. fast_output .and. unitfast > 1)         &
          ) then
      frqsum=day_sec
   !---------------------------------------------------------------------------------------!
   !    Only restarts, and the unit is in seconds, test which frqsum to use.               !
   !---------------------------------------------------------------------------------------!
   elseif (no_fast_output .and. isoutput > 0) then
      frqsum=min(frqstate,day_sec)
   !---------------------------------------------------------------------------------------!
   !    Only fast analysis, and the unit is in seconds, test which frqsum to use.          !
   !---------------------------------------------------------------------------------------!
   elseif (isoutput == 0 .and. fast_output) then
      frqsum=min(frqfast,day_sec)
   !---------------------------------------------------------------------------------------!
   !    Both are on and both outputs are in seconds or day scales. Choose the minimum      !
   ! between them and one day.                                                             !
   !---------------------------------------------------------------------------------------!
   elseif (unitfast < 2 .and. unitstate < 2) then 
      frqsum=min(min(frqstate,frqfast),day_sec)
   !---------------------------------------------------------------------------------------!
   !    Both are on but unitstate is in month or years. Choose the minimum between frqfast !
   ! and one day.                                                                          !
   !---------------------------------------------------------------------------------------!
   elseif (unitfast < 2) then 
      frqsum=min(frqfast,day_sec)
   !---------------------------------------------------------------------------------------!
   !    Both are on but unitfast is in month or years. Choose the minimum between frqstate !
   ! and one day.                                                                          !
   !---------------------------------------------------------------------------------------!
   else
      frqsum=min(frqstate,day_sec)
   end if
   !---------------------------------------------------------------------------------------!




   !---------------------------------------------------------------------------------------!
   !     Find some useful conversion factors.                                              !
   ! 1. FRQSUMI         -- inverse of the elapsed time between two analyses (or one day).  !
   !                       This should be used by variables that are fluxes and are solved !
   !                       by RK4, they are holding the integral over the past frqsum      !
   !                       seconds.                                                        !
   ! 2. DTLSM_O_FRQSUM  -- inverse of the number of the main time steps (DTLSM) since      !
   !                       previous analysis.  Only photosynthesis- and decomposition-     !
   !                       related variables, or STATE VARIABLES should use this factor.   !
   !                       Do not use this for energy and water fluxes, CO2 eddy flux, and !
   !                       CO2 storage.                                                    !
   ! 3. RADFRQ_O_FRQSUM -- inverse of the number of radiation time steps since the         !
   !                       previous analysis.  Only radiation-related variables should use !
   !                       this factor.                                                    !
   !---------------------------------------------------------------------------------------!
   frqsumi         = 1.0    / frqsum
   dtlsm_o_frqsum  = dtlsm  * frqsumi
   radfrq_o_frqsum = radfrq * frqsumi
   !---------------------------------------------------------------------------------------!


   return
end subroutine find_frqsum
!==========================================================================================!
!==========================================================================================!






!==========================================================================================!
!==========================================================================================!
!    This sub-routine eliminates all patches except the one you want to save...  This      !
! shouldn't be used unless you are debugging the code.                                     !
!------------------------------------------------------------------------------------------!
subroutine exterminate_patches_except(keeppa)
   use ed_state_vars  , only : edgrid_g           & ! structure
                             , edtype             & ! structure
                             , polygontype        & ! structure
                             , sitetype           & ! structure
                             , patchtype          ! ! structure
   use grid_coms      , only : ngrids             ! ! intent(in)
   use fuse_fiss_utils, only : terminate_patches  ! ! sub-routine

   implicit none

   !----- Arguments -----------------------------------------------------------------------!
   integer                        , intent(in)  :: keeppa
   !----- Local variables -----------------------------------------------------------------!
   type(edtype)                   , pointer     :: cgrid
   type(polygontype)              , pointer     :: cpoly
   type(sitetype)                 , pointer     :: csite
   type(patchtype)                , pointer     :: cpatch
   integer                                      :: ifm
   integer                                      :: ipy
   integer                                      :: isi
   integer                                      :: ipa
   integer                                      :: keepact
   real             , dimension(:), allocatable :: csite_lai
   !---------------------------------------------------------------------------------------!


   gridloop: do ifm=1,ngrids
      cgrid => edgrid_g(ifm)

      polyloop: do ipy=1,cgrid%npolygons
         cpoly => cgrid%polygon(ipy)

         siteloop: do isi=1,cpoly%nsites
            csite => cpoly%site(isi)

            select case(keeppa)
            case (0)
               return
            case (-2)
               !----- Keep the one with the lowest LAI. -----------------------------------!
               allocate(csite_lai(csite%npatches))
               csite_lai(:) = 0.0
               keepm2loop: do ipa=1,csite%npatches
                  cpatch => csite%patch(ipa)
                  if (cpatch%ncohorts > 0) csite_lai(ipa) = sum(cpatch%lai)
               end do keepm2loop
               keepact = minloc(csite_lai,dim=1)
               deallocate(csite_lai)
               !---------------------------------------------------------------------------!
            case (-1)
               !----- Keep the one with the lowest LAI. -----------------------------------!
               allocate(csite_lai(csite%npatches))
               csite_lai(:) = 0.0
               keepm1loop: do ipa=1,csite%npatches
                  cpatch => csite%patch(ipa)
                  if (cpatch%ncohorts > 0) csite_lai(ipa) = sum(cpatch%lai)
               end do keepm1loop
               keepact = maxloc(csite_lai,dim=1)
               deallocate(csite_lai)
               !---------------------------------------------------------------------------!
            case default
               !----- Keep a fixed patch number. ------------------------------------------!
               keepact = keeppa
               
               if (keepact > csite%npatches) then
                  write(unit=*,fmt='(a)')       '-----------------------------------------'
                  write(unit=*,fmt='(a,1x,i6)') ' - IPY      = ',ipy
                  write(unit=*,fmt='(a,1x,i6)') ' - ISI      = ',isi
                  write(unit=*,fmt='(a,1x,i6)') ' - NPATCHES = ',csite%npatches
                  write(unit=*,fmt='(a,1x,i6)') ' - KEEPPA   = ',keeppa
                  write(unit=*,fmt='(a)')       '-----------------------------------------'
                  call fail_whale ()
                  call fatal_error('KEEPPA can''t be greater than NPATCHES'                &
                                  ,'exterminate_patches_except','ed_driver.f90')
               end if
            end select

            patchloop: do ipa=1,csite%npatches
               if (ipa == keepact) then
                  csite%area(ipa) = 1.0
               else
                  csite%area(ipa) = 0.0
               end if
            end do patchloop

            call terminate_patches(csite)

         end do siteloop
      end do polyloop
   end do gridloop

   return
end subroutine exterminate_patches_except
!==========================================================================================!
!==========================================================================================!
