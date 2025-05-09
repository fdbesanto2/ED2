!==========================================================================================!
!==========================================================================================!
!      Subroutine based on RAMS, just to output error messages and halts the execution     !
!  properly. You should alway use this one, since it checks whether the run is running in  !
!  parallel. If so, it will use MPI_Abort rather than stop, so it will exit rather than    !
!  being frozen.                                                                           !
!------------------------------------------------------------------------------------------!
subroutine fatal_error(reason,subr,file)
   use ed_node_coms   , only : nnodetot       & ! intent(in)
                             , mynum          ! ! intent(in)
#if defined(RAMS_MPI)
   use mpi
#endif
   implicit none
   !----- Arguments. ----------------------------------------------------------------------!
   character(len=*), intent(in) :: reason
   character(len=*), intent(in) :: subr
   character(len=*), intent(in) :: file
   !----- Local variables. ----------------------------------------------------------------!
   logical                      :: parallel
   logical                      :: slavenode
   !---------------------------------------------------------------------------------------!


   !---------------------------------------------------------------------------------------!
   !       Check which type of end we should use.  For the main program, this should never !
   ! attempt to reference the parallel stuff.                                              !
   !---------------------------------------------------------------------------------------!
   if (trim(file) == 'edmain.F90' .or. trim(file) == 'rammain.F90') then
      parallel  = .false.
      slavenode = .false.
   else
      parallel  = nnodetot > 1
      slavenode = mynum    /= nnodetot
   end if
   !---------------------------------------------------------------------------------------!

   write(unit=*,fmt='(a)') '::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
   write(unit=*,fmt='(a)') '::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
   write(unit=*,fmt='(a)') '::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
   write(unit=*,fmt='(a)') ' '
   write(unit=*,fmt='(a)') '--------------------------------------------------------------'
   write(unit=*,fmt='(a)') '                     !!! FATAL ERROR !!!                      '
   write(unit=*,fmt='(a)') '--------------------------------------------------------------'
   if (slavenode) then
      write (unit=*,fmt='(a,1x,i5,a)') ' On node: ',mynum,':'
   elseif (parallel) then
      write (unit=*,fmt='(a)')         ' On the master node:'
   end if
   write (unit=*,fmt='(a,1x,a)')       '    ---> File:       ',trim(file)
   write (unit=*,fmt='(a,1x,a)')       '    ---> Subroutine: ',trim(subr)
   write (unit=*,fmt='(a,1x,a)')       '    ---> Reason:     ',trim(reason)
   write(unit=*,fmt='(a)') '--------------------------------------------------------------'
   write(unit=*,fmt='(a)') ' ED execution halts (see previous error message)...'
   write(unit=*,fmt='(a)') '--------------------------------------------------------------'

   !---------------------------------------------------------------------------------------!
   !     Remind the user of deprecated ED2IN choices...                                    !
   !---------------------------------------------------------------------------------------!
#if defined(RAMS_MPI)
   if (parallel) call MPI_Abort(MPI_COMM_WORLD, 1)
#endif
   stop 'fatal_error'
end subroutine fatal_error
!==========================================================================================!
!==========================================================================================!






!==========================================================================================!
!==========================================================================================!
!   This is just a first warning to be given in the standard output. Since the namelist    !
! may have more than one error, I list all the problems, then the model will stop.         !
!------------------------------------------------------------------------------------------!
subroutine opspec_fatal(reason,opssub)
   implicit none
   character(len=*), intent(in) :: reason,opssub

   write (unit=*,fmt='(a)')       ' '
   write (unit=*,fmt='(a)')       '------------------------------------------------------'
   write (unit=*,fmt='(3(a,1x))') '>>>> ',trim(opssub),' error! in your namelist!'
   write (unit=*,fmt='(a,1x,a)')  '    ---> Reason:     ',trim(reason)
   write (unit=*,fmt='(a)')       '------------------------------------------------------'
   write (unit=*,fmt='(a)')       ' '
   return
end subroutine opspec_fatal
!==========================================================================================!
!==========================================================================================!






!==========================================================================================!
!==========================================================================================!
!  Warning message, does not exit                                                          !
!------------------------------------------------------------------------------------------!
subroutine warning(reason,subr,file)

   use ed_node_coms, only: nnodetot,mynum
   implicit none
   character(len=*), intent(in) :: reason
   character(len=*), intent(in) :: subr,file
  
   write(unit=*,fmt='(a)') '::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
   write(unit=*,fmt='(a)') '::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
   write(unit=*,fmt='(a)') '::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
   write(unit=*,fmt='(a)') ' '
   write(unit=*,fmt='(a)') '--------------------------------------------------------------'
   write(unit=*,fmt='(a)') '                     !!! WARNING !!!                          '
   write(unit=*,fmt='(a)') '--------------------------------------------------------------'
   if (nnodetot > 1 .and. mynum /= nnodetot) then
      write(unit=*,fmt='(a,1x,i5,a)') ' On node: ',mynum,':'
   elseif (nnodetot > 1) then
      write(unit=*,fmt='(a)')         ' On the master node:'
   end if
   ! Although it is optional, it should always be present 
   write(unit=*,fmt='(a,1x,a)')    '    ---> File:       ',trim(file)
   write(unit=*,fmt='(a,1x,a)')    '    ---> Subroutine: ',trim(subr)
   write (unit=*,fmt='(a,1x,a)')   '    ---> Reason:     ',trim(reason)
   write(unit=*,fmt='(a)') '--------------------------------------------------------------'
   write(unit=*,fmt='(a)') '--------------------------------------------------------------'
 end subroutine warning
!==========================================================================================!
!==========================================================================================!






!==========================================================================================!
!==========================================================================================!
subroutine fail_whale()

   implicit none


   write(unit=*,fmt='(a)') ''
   write(unit=*,fmt='(a)') ''
   write(unit=*,fmt='(a)') ':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'
   write(unit=*,fmt='(a)') '                                                                           '
   write(unit=*,fmt='(a)') '    ___ _  _ ____    ____ ____ _ _       _ _ _ _  _ ____ _    ____         '
   write(unit=*,fmt='(a)') '     |  |__| |___    |___ |__| | |       | | | |__| |__| |    |___         '
   write(unit=*,fmt='(a)') '     |  |  | |___    |    |  | | |___    |_|_| |  | |  | |___ |___         '
   write(unit=*,fmt='(a)') '                                                                           '
   write(unit=*,fmt='(a)') '       _  _ ____ ____    ____ ____ ____ ____ _  _ ____ ___                 '
   write(unit=*,fmt='(a)') '       |__| |__| [__     |    |__/ |__| [__  |__| |___ |  \                '
   write(unit=*,fmt='(a)') '       |  | |  | ___]    |___ |  \ |  | ___] |  | |___ |__/                '
   write(unit=*,fmt='(a)') '                                                                           ' 
   write(unit=*,fmt='(a)') '       _ _  _ ___ ____    _   _ ____ _  _ ____    ____ _ _  _              '
   write(unit=*,fmt='(a)') '       | |\ |  |  |  |     \_/  |  | |  | |__/    [__  | |\/|              '
   write(unit=*,fmt='(a)') '       | | \|  |  |__|      |   |__| |__| |  \    ___] | |  |              '
   write(unit=*,fmt='(a)') '                                                                           '
   write(unit=*,fmt='(a)') '                                                                           '
   write(unit=*,fmt='(a)') '                                                                           '
   write(unit=*,fmt='(a)') '                                             .+shhhhhhhhhhyso/-`           '
   write(unit=*,fmt='(a)') '             `.-::///+oooooooooooo+/:.`     -hhhhhhhhhhhhhhhhhhhs+.        '
   write(unit=*,fmt='(a)') '        -/oyhhhhhhhhhhhhhhhhhhhhhhhhhhhyo:` -hhhhhhhhhhhhhhhhhhhhhhy/      '
   write(unit=*,fmt='(a)') '     -ohhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhs:-oyhhhhhhhhhhhhhhhhhhhhhy-    '
   write(unit=*,fmt='(a)') '   -yhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhy/ `-+yhhhhhhhhhhhhhhhhhhh+   '
   write(unit=*,fmt='(a)') '  +hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhy:   :yhhhhhhhhhhhhhhhhhho  '
   write(unit=*,fmt='(a)') ' ohhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhho`  `yhhhhhhhhhhhhhhhhhh+ '
   write(unit=*,fmt='(a)') '/hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhy-  .hhhhhhhhhhyshhhhhhh-'
   write(unit=*,fmt='(a)') 'yhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhs` +hhhhhhhh:  .hhhhhhs'
   write(unit=*,fmt='(a)') 'hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh/`yhhhhhy.    shhhhhh'
   write(unit=*,fmt='(a)') 'hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh+/+o+:     :hhhhhhh'
   write(unit=*,fmt='(a)') 'hhhhhhhhhhhhhhh::yhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhso////+ohhhhhhhhs'
   write(unit=*,fmt='(a)') 'yhhhhhhhhhhhhhh+/yhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh.'
   write(unit=*,fmt='(a)') '/hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh: '
   write(unit=*,fmt='(a)') ' ohhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhs.  '
   write(unit=*,fmt='(a)') '  /hhhhhhhhhhhoohhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhho-    '
   write(unit=*,fmt='(a)') '   `:/+++/////shhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhsosyyyys+:.       '
   write(unit=*,fmt='(a)') '    -hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh::+/              '
   write(unit=*,fmt='(a)') '     :/++++yhhhhhhhhhhs++oyhhhhhhhhhhs+++ohhhhhhs+/ohhhhhhhy:              '
   write(unit=*,fmt='(a)') '           /shhhhhs+-      `:+oso+/.       .::-     `:///-.                '
   write(unit=*,fmt='(a)') '                                                                           '
   write(unit=*,fmt='(a)') '                                                                           '
   write(unit=*,fmt='(a)') '                                                                           '
   write(unit=*,fmt='(a)') ':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::'

   return
end subroutine fail_whale
!==========================================================================================!
!==========================================================================================!
