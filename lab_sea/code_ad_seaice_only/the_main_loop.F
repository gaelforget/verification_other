#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

#ifdef ALLOW_OBCS
# include "OBCS_OPTIONS.h"
#endif
#ifdef ALLOW_SEAICE
# include "SEAICE_OPTIONS.h"
#endif
#ifdef ALLOW_GMREDI
# include "GMREDI_OPTIONS.h"
#endif

      subroutine the_main_loop( myTime, myIter, mythid )

c     ==================================================================
c     SUBROUTINE the_main_loop
c     ==================================================================
c
c     o Run the ocean model and evaluate the specified cost function.
c
c     *the_main_loop* is the top-level routine for the Tangent Linear and
c     Adjoint Model Compiler (TAMC). For this purpose, the initialization
c     of the model was split into two parts. Those parameters that do
c     not depend on a specific model run are set in *initialise_fixed*,
c     whereas those that do depend on the specific realization are
c     initialized in *initialise_varia*. In order to do a so called
c     checkpointing during the adjoint calculation and to account for the
c     typical data involved in oceanographic applications a call tree
c     that is divided into yearly, monthly, daily, and step parts can
c     be used.
c
c     This routine is to be used in conjuction with the MITgcmuv release
c     checkpoint 24.
c
c     started: Christian Eckert eckert@mit.edu 30-Jun-1999
c
c     changed: Christian Eckert eckert@mit.edu 14-Jul-1999
c
c              - The call to mapping was moved to initialise_varia,
c                since this routine has to be called before 
c                ini_predictor.
c
c              Christian Eckert eckert@mit.edu 11-Feb-2000
c
c              - Restructured the code in order to create a package
c                for the MITgcmUV.
c
c              Patrick Heimbach heimbach@mit.edu 3-Jun-2000
c              - corrected computation of ikey_dynamics and
c                added computation of ikey_dynamics for the case
c                undef ALLOW_TAMC_CHECKPOINTING
c
c              Patrick Heimbach heimbach@mit.edu 6-Jun-2000
c              - corrected initialisation of comlev1 common blocks
c
c              Dimitris Menemenlis  menemenlis@jpl.nasa.gov 26-Feb-2003
c              - modifications for pkg/seaice
c
c     ==================================================================
c     SUBROUTINE the_main_loop
c     ==================================================================

      implicit none

c     == global variables ==

#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"

c**************************************
#ifdef ALLOW_AUTODIFF_TAMC

c These includes are needed for 
c AD-checkpointing. 
c They provide the fields to be stored.

# include "GRID.h"
# include "DYNVARS.h"
# include "FFIELDS.h"
# include "EOS.h"

# ifdef ALLOW_GENERIC_ADVDIFF
#  include "GAD.h"
# endif
# ifdef ALLOW_CD_CODE
#  include "CD_CODE_VARS.h"
# endif
# ifdef ALLOW_PTRACERS
#  include "PTRACERS_SIZE.h"
#  include "PTRACERS.h"
# endif
# ifdef ALLOW_NONHYDROSTATIC
#  include "CG3D.h"
# endif
# ifdef EXACT_CONSERV
#  include "SURFACE.h"
# endif
# ifdef ALLOW_OBCS
#  include "OBCS.h"
# endif
# ifdef ALLOW_EXF
#  include "EXF_FIELDS.h"
#  ifdef ALLOW_BULKFORMULAE
#   include "EXF_CONSTANTS.h"
#  endif
# endif /* ALLOW_EXF */
# ifdef ALLOW_SEAICE
#  include "SEAICE.h"
#  include "SEAICE_COST.h"
# endif
# ifdef ALLOW_KPP
#  include "KPP.h"
# endif
# ifdef ALLOW_GMREDI
#  include "GMREDI.h"
# endif
# ifdef ALLOW_DIVIDED_ADJOINT_MPI
#  include "mpif.h"
# endif

# include "tamc.h"
# include "ctrl.h"
# include "ctrl_dummy.h"
# include "cost.h"
# include "ecco_cost.h"

#endif /* ALLOW_AUTODIFF_TAMC */
c**************************************

c     == routine arguments ==
c     note: under the multi-threaded model myiter and 
c           mytime are local variables passed around as routine 
c           arguments. Although this is fiddly it saves the need to 
c           impose additional synchronisation points when they are 
c           updated.
c     myiter - iteration counter for this thread
c     mytime - time counter for this thread
c     mythid - thread number for this instance of the routine.
      integer mythid 
      integer myiter
      _RL     mytime 

c     == local variables ==

      integer bi,bj
      integer iloop
      integer mydate(4)
#ifdef ALLOW_SNAPSHOTS
      character yprefix*3
#endif

#ifdef ALLOW_TAMC_CHECKPOINTING
      integer ilev_1
      integer ilev_2
      integer ilev_3
      integer max_lev2
      integer max_lev3
#endif

c--   == end of interface ==

#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_ENTER('THE_MAIN_LOOP',myThid)
#endif

#ifdef ALLOW_AUTODIFF_TAMC
c--   Initialize storage for the initialisations.
CADJ INIT tapelev_ini_bibj_k   = USER
CADJ INIT tapelev_init = USER
#ifdef AUTODIFF_2_LEVEL_CHECKPOINT
CADJ  INIT tapelev2 = USER
#else
CADJ  INIT tapelev3 = USER
#endif
CADJ INIT onetape = user
cphCADJ INIT onetape = common, 1
cph We want to avoid common blocks except in the inner loop.
cph Reason: the active write and consecutive read may occur
cph         in separate model executions for which the info
cph         in common blocks are lost.
cph Thus, we can only store real values (no integers)
cph because we only have active file handling to real available.
# ifdef ALLOW_TAMC_CHECKPOINTING
       ikey_dynamics = 1
# endif
CADJ STORE mytime = onetape
#endif /* ALLOW_AUTODIFF_TAMC */

      CALL TIMER_START('ECCO SPIN-UP', mythid)

c--   Get the current date.
      call CAL_TIMESTAMP( myiter, mytime, mydate, mythid )

C--   Set initial conditions (variable arrays)
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('INITIALISE_VARIA',myThid)
#endif
      CALL TIMER_START('INITIALISE_VARIA    [THE_MAIN_LOOP]', mythid)
      CALL INITIALISE_VARIA( mythid )
      CALL TIMER_STOP ('INITIALISE_VARIA    [THE_MAIN_LOOP]', mythid)

      call timer_stop ('ECCO SPIN-UP', mythid)
      _BARRIER

c--   Do the model integration.
      call timer_start('ECCO MAIN LOOP',mythid)

c     >>>>>>>>>>>>>>>>>>>>>>>>>>>   LOOP   <<<<<<<<<<<<<<<<<<<<<<<<<<<<
c     >>>>>>>>>>>>>>>>>>>>>>>>>>>  STARTS  <<<<<<<<<<<<<<<<<<<<<<<<<<<<

#ifdef ALLOW_AUTODIFF_TAMC
#ifdef ALLOW_TAMC_CHECKPOINTING

      max_lev3=nTimeSteps/(nchklev_1*nchklev_2)+1
      max_lev2=nTimeSteps/nchklev_1+1

c**************************************
#ifdef ALLOW_DIVIDED_ADJOINT
CADJ loop = divided
#endif
c**************************************

#ifndef AUTODIFF_2_LEVEL_CHECKPOINT

      do ilev_3 = 1,nchklev_3
         if(ilev_3.le.max_lev3) then
c**************************************
#include "checkpoint_lev3_directives.h"
c**************************************

c--     Initialise storage for the middle loop.
CADJ    INIT tapelev2 = USER

#endif /* AUTODIFF_2_LEVEL_CHECKPOINT */

        do ilev_2 = 1,nchklev_2
         if(ilev_2.le.max_lev2) then
c**************************************
#include "checkpoint_lev2_directives.h"
c**************************************

c**************************************
#ifdef ALLOW_AUTODIFF_TAMC
c--       Initialize storage for the innermost loop.
c--       Always check common block sizes for the checkpointing!
c--
CADJ INIT comlev1        = COMMON,nchklev_1
CADJ INIT comlev1_bibj   = COMMON,nchklev_1*nsx*nsy*nthreads_chkpt
CADJ INIT comlev1_bibj_k = COMMON,nchklev_1*nsx*nsy*nr*nthreads_chkpt
c--
# ifdef ALLOW_KPP
CADJ INIT comlev1_kpp    = COMMON,nchklev_1*nsx*nsy
CADJ INIT comlev1_kpp_k  = COMMON,nchklev_1*nsx*nsy*nr
# endif /* ALLOW_KPP */
c--
# ifdef ALLOW_GMREDI
CADJ INIT comlev1_gmredi_k_gad
CADJ &    = COMMON,nchklev_1*nsx*nsy*nr*nthreads_chkpt*maxpass
# endif /* ALLOW_GMREDI */
c--
# ifdef ALLOW_PTRACERS
CADJ INIT comlev1_bibj_ptracers = COMMON,
CADJ &    nchklev_1*nsx*nsy*nthreads_chkpt*PTRACERS_num
# endif /* ALLOW_PTRACERS */
c--
# ifndef DISABLE_MULTIDIM_ADVECTION
CADJ INIT comlev1_bibj_k_gad
CADJ &    = COMMON,nchklev_1*nsx*nsy*nr*nthreads_chkpt*maxpass
CADJ INIT comlev1_bibj_k_gad_pass
CADJ &    = COMMON,nchklev_1*nsx*nsy*nr*nthreads_chkpt*maxpass*maxcube
# endif /* DISABLE_MULTIDIM_ADVECTION */
c--
# if (defined (ALLOW_EXF) && defined (ALLOW_BULKFORMULAE))
CADJ INIT comlev1_exf_1
CADJ &     = COMMON,nchklev_1*snx*nsx*sny*nsy*nthreads_chkpt
CADJ INIT comlev1_exf_2
CADJ &     = COMMON,niter_bulk*nchklev_1*snx*nsx*sny*nsy*nthreads_chkpt
# endif
c--
# ifdef ALLOW_SEAICE
#  ifdef SEAICE_ALLOW_DYNAMICS
CADJ INIT comlev1_lsr = COMMON,nchklev_1*2
#  endif
#  ifdef SEAICE_MULTILEVEL
CADJ INIT comlev1_multdim 
CADJ &    = COMMON,nchklev_1*nsx*nsy*nthreads_chkpt*multdim
#  endif
# endif /* ALLOW_SEAICE */
c--
#endif /* ALLOW_AUTODIFF_TAMC */
c**************************************

          do ilev_1 = 1,nchklev_1

c--         The if-statement below introduces a some flexibility in the
c--         choice of the 3-tupel ( nchklev_1, nchklev_2, nchklev_3 ).
c--
c--         Requirement: nchklev_1*nchklev_2*nchklev_3 .ge. nTimeSteps .

            iloop = (ilev_2 - 1)*nchklev_1           + ilev_1
#ifndef AUTODIFF_2_LEVEL_CHECKPOINT
     &            + (ilev_3 - 1)*nchklev_2*nchklev_1
#endif

            if ( iloop .le. nTimeSteps ) then

#else /* ALLOW_TAMC_CHECKPOINTING  undefined */
c--   Initialise storage for the reference trajectory without TAMC check-
c--   pointing.
CADJ INIT history        = USER
CADJ INIT comlev1_bibj   = COMMON,nchklev_0*nsx*nsy*nthreads_chkpt
CADJ INIT comlev1_bibj_k = COMMON,nchklev_0*nsx*nsy*nr*nthreads_chkpt
CADJ INIT comlev1_kpp    = COMMON,nchklev_0*nsx*nsy

c--   Check the choice of the checkpointing parameters in relation
c--   to nTimeSteps: (nchklev_0 .ge. nTimeSteps)
      if (nchklev_0 .lt. nTimeSteps) then
        print*
        print*, ' the_main_loop: ',
     &       'TAMC checkpointing parameter nchklev_0 = ', 
     &       nchklev_0
        print*, '            is not consistent with nTimeSteps = ', 
     &       nTimeSteps
        stop    ' ... stopped in the_main_loop.'
      endif

      do iloop = 1, nTimeSteps

#endif /* ALLOW_TAMC_CHECKPOINTING */

#else /* ALLOW_AUTODIFF_TAMC  undefined */
c--   Start the main loop of ecco_Objfunc. Automatic differentiation is
c--   NOT enabled.
      do iloop = 1, nTimeSteps
#endif /* ALLOW_AUTODIFF_TAMC */

#ifdef ALLOW_TAMC_CHECKPOINTING
        nIter0 = NINT( (startTime-baseTime)/deltaTClock )
        ikey_dynamics = ilev_1
#endif

c--     Set the model iteration counter and the model time.
        myiter = nIter0 + (iloop-1)
        mytime = startTime + float(iloop-1)*deltaTclock

#ifdef ALLOW_AUTODIFF_TAMC
        CALL AUTODIFF_INADMODE_UNSET( myThid )
#endif

#ifdef ALLOW_COST

c--     Accumulate time averages of temperature, salinity, and SSH.
        call timer_start('COST_AVERAGESFIELDS   [ECCO MAIN]', mythid)
        call cost_averagesFields( mytime, mythid )
        call timer_stop ('COST_AVERAGESFIELDS   [ECCO MAIN]', mythid)
#ifdef ALLOW_COST_ATLANTIC
c--     Compute meridional heat transport 
        call timer_start('cost_atlantic         [ECCO MAIN]', mythid)
        call cost_atlantic(  mytime, myiter,mythid )
        call timer_stop ('cost_atlantic         [ECCO MAIN]', mythid)
#endif
#endif /* ALLOW_COST */

#ifdef ALLOW_AUTODIFF_TAMC
c**************************************
#include "checkpoint_lev1_directives.h"
c**************************************
#endif

#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('EXF_GETFORCING',myThid)
#endif
      CALL TIMER_START('EXF_GETFORCING     [FORWARD_STEP]',mythid)
      CALL EXF_GETFORCING( mytime, myiter, mythid )
      CALL TIMER_STOP ('EXF_GETFORCING     [FORWARD_STEP]',mythid)

#ifdef ALLOW_AUTODIFF_TAMC
# if (defined (ALLOW_AUTODIFF_MONITOR))
        CALL DUMMY_IN_STEPPING( myTime, myIter, myThid )
# endif
#endif

#ifdef ALLOW_SEAICE
cph this simple runtime flag causes a lot of recomp.
      IF ( useSEAICE ) THEN
#ifndef DISABLE_DEBUGMODE
         IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('SEAICE_MODEL',myThid)
#endif
#ifdef ALLOW_AUTODIFF_TAMC
CADJ STORE area    = comlev1, key = ikey_dynamics
cph-new(
CADJ STORE atemp   = comlev1, key = ikey_dynamics
CADJ STORE aqh     = comlev1, key = ikey_dynamics
CADJ STORE precip  = comlev1, key = ikey_dynamics
CADJ STORE swdown  = comlev1, key = ikey_dynamics
CADJ STORE lwdown  = comlev1, key = ikey_dynamics
CADJ STORE theta   = comlev1, key = ikey_dynamics
cph-new)
#endif
         CALL TIMER_START('SEAICE_MODEL       [FORWARD_STEP]',myThid)
         CALL SEAICE_MODEL( myTime, myIter, myThid )
         CALL TIMER_STOP ('SEAICE_MODEL       [FORWARD_STEP]',myThid)
#ifdef ALLOW_COST_ICE
         CALL COST_ICE_TEST    ( myTime, myIter, myThid )
#endif
      ENDIF
#endif /* ALLOW_SEAICE */

#ifdef ALLOW_AUTODIFF_TAMC
# ifdef ALLOW_PTRACERS
cph this replaces _bibj storing of ptracer within thermodynamics
CADJ STORE ptracer  = comlev1, key = ikey_dynamics
# endif
#endif

#ifndef ALLOW_OFFLINE
#ifdef ALLOW_DEBUG
       IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('DO_OCEANIC_PHYS',myThid)
#endif
       CALL TIMER_START('DO_OCEANIC_PHYS     [FORWARD_STEP]',mythid)
       CALL DO_OCEANIC_PHYS( myTime, myIter, myThid )
       CALL TIMER_STOP ('DO_OCEANIC_PHYS     [FORWARD_STEP]',mythid)
#endif

C--   Update time-counter
      myIter = nIter0 + iLoop
      myTime = startTime + deltaTClock * float(iLoop)

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|


#ifdef ALLOW_AUTODIFF_TAMC
        CALL AUTODIFF_INADMODE_SET( myThid )
#endif

C--   State-variables statistics (time-aver, diagnostics ...)
      CALL TIMER_START('DO_STATEVARS_DIAGS  [FORWARD_STEP]',myThid)
      CALL DO_STATEVARS_DIAGS( myTime, myIter, myThid )
      CALL TIMER_STOP ('DO_STATEVARS_DIAGS  [FORWARD_STEP]',myThid)

#ifdef ALLOW_MONITOR
C--   Check status of solution (statistics, cfl, etc...)
      CALL TIMER_START('MONITOR             [FORWARD_STEP]',myThid)
      CALL MONITOR( myIter, myTime, myThid )
      CALL TIMER_STOP ('MONITOR             [FORWARD_STEP]',myThid)
#endif /* ALLOW_MONITOR */

C--   Do IO if needed.
#ifdef ALLOW_OFFLINE
      CALL TIMER_START('OFFLINE_MODEL_IO     [FORWARD_STEP]',myThid)
      CALL OFFLINE_MODEL_IO( myTime, myIter, myThid )
      CALL TIMER_STOP ('OFFLINE_MODEL_IO     [FORWARD_STEP]',myThid)
#else
      CALL TIMER_START('DO_THE_MODEL_IO     [FORWARD_STEP]',myThid)
      CALL DO_THE_MODEL_IO( myTime, myIter, myThid )
      CALL TIMER_STOP ('DO_THE_MODEL_IO     [FORWARD_STEP]',myThid)
#endif

#ifdef ALLOW_AUTODIFF_TAMC
#ifdef ALLOW_TAMC_CHECKPOINTING
            endif
          enddo
          endif
        enddo
#ifndef AUTODIFF_2_LEVEL_CHECKPOINT
        endif
      enddo
#endif
#else
      enddo
#endif

#else
      enddo
#endif /* ALLOW_AUTODIFF_TAMC */

      _BARRIER
      call timer_stop ('ECCO MAIN LOOP', mythid)

      call timer_start('ECCO SPIN-DOWN', mythid)

#ifdef ALLOW_COST

#ifdef ALLOW_DIVIDED_ADJOINT
CADJ STORE mytime = onetape
#endif
c--   Accumulate time averages of temperature, salinity, and SSH.
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_averagesfields',myThid)
#endif
      call timer_start('cost_averagesfields [ECCO SPIN-DOWN]', mythid)
      call cost_averagesfields( mytime, mythid )
      call timer_stop ('cost_averagesfields [ECCO SPIN-DOWN]', mythid)
#ifdef ALLOW_DIVIDED_ADJOINT
c**************************************
#include "cost_averages_bar_directives.h"
c**************************************
#endif

#ifdef ALLOW_COST_ATLANTIC
c--   Compute meridional heat transport 
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_atlantic',myThid)
#endif
      call timer_start('cost_atlantic      [ECCO SPIN-DOWN]', mythid)
      call cost_atlantic(  mytime, myiter,mythid )
      call timer_stop ('cost_atlantic      [ECCO SPIN-DOWN]', mythid)
#endif

c--   Compute the cost function contribution of the boundary forcing,
c--   i.e. heat flux, salt flux, zonal and meridional wind stress.
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_forcing',myThid)
#endif
      call timer_start('cost_forcing       [ECCO SPIN-DOWN]', mythid)
      call cost_forcing( myiter, mytime, mythid )
      call timer_stop ('cost_forcing       [ECCO SPIN-DOWN]', mythid)

c--   Compute cost function contribution of Temperature and Salinity.
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_hyd',myThid)
#endif
      call timer_start('cost_hyd           [ECCO SPIN-DOWN]', mythid)
      call cost_hyd( myiter, mytime, mythid )
      call timer_stop ('cost_hyd           [ECCO SPIN-DOWN]', mythid)

#ifdef ALLOW_SEAICE
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('seaice_cost_driver',myThid)
#endif
      call timer_start('seaice_cost_driver [ECCO SPIN-DOWN]', mythid)
      call seaice_cost_driver( myiter, mytime, mythid )
      call timer_stop ('seaice_cost_driver [ECCO SPIN-DOWN]', mythid)
#endif

#ifdef ALLOW_OBCS_COST_CONTRIBUTION
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_obcs',myThid)
#endif
      call timer_start('cost_obcs          [ECCO SPIN-DOWN]', mythid)
      call cost_obcs( myiter, mytime, mythid )
      call timer_stop ('cost_obcs          [ECCO SPIN-DOWN]', mythid)
#endif

#ifdef ALLOW_CURMTR_COST_CONTRIBUTION
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_curmtr',myThid)
#endif
      call timer_start('cost_curmtr        [ECCO SPIN-DOWN]', mythid)
      call cost_curmtr( myiter, mytime, mythid )
      call timer_stop ('cost_curmtr        [ECCO SPIN-DOWN]', mythid)
#endif

c--   Compute cost function contribution of SSH.
#ifdef ALLOW_SSH_COST_CONTRIBUTION
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_ssh',myThid)
#endif
      call timer_start('cost_ssh           [ECCO SPIN-DOWN]', mythid)
      call cost_ssh( myiter, mytime, mythid )
      call timer_stop ('cost_ssh           [ECCO SPIN-DOWN]', mythid)
#endif

c--   Compute cost function contribution of drifter's velocities.
#ifdef ALLOW_DRIFTER_COST_CONTRIBUTION
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_drifter',myThid)
#endif
      call timer_start('cost_drifter         [ECCO SPIN-DOWN]', mythid)
      call cost_drifter( myiter, mytime, mythid )
      call timer_stop ('cost_drifter         [ECCO SPIN-DOWN]', mythid)
#endif

c--   Compute cost function contribution of wind stress observations.
#ifdef ALLOW_SCAT_COST_CONTRIBUTION
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_scat',myThid)
#endif
      call timer_start('cost_scat            [ECCO SPIN-DOWN]', mythid) 
      call cost_scat( myiter, mytime, mythid )
      call timer_stop ('cost_scat            [ECCO SPIN-DOWN]', mythid)
#endif

c--   Compute cost function contribution of wind stress observations.  
#ifdef ALLOW_MEAN_HFLUX_COST_CONTRIBUTION
      call timer_start('cost_mean_heatflux   [ECCO SPIN-DOWN]', mythid)
      call cost_mean_heatflux( myiter, mytime, mythid )
      call timer_stop ('cost_mean_heatflux   [ECCO SPIN-DOWN]', mythid)
#endif

c--   Compute cost function contribution of wind stress observations.
#ifdef ALLOW_MEAN_SFLUX_COST_CONTRIBUTION
      call timer_start('cost_mean_saltflux   [ECCO SPIN-DOWN]', mythid)
      call cost_mean_saltflux( myiter, mytime, mythid )
      call timer_stop ('cost_mean_saltflux   [ECCO SPIN-DOWN]', mythid)        
#endif

c--   Compute cost function contribution of drift between the first 
c     and the last year.
#ifdef ALLOW_DRIFT_COST_CONTRIBUTION
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_drift',myThid)
#endif
      call timer_start('cost_drift         [ECCO SPIN-DOWN]', mythid)
      call cost_drift( myiter, mytime, mythid )
      call timer_stop ('cost_drift         [ECCO SPIN-DOWN]', mythid)
#endif
#ifdef ALLOW_DRIFTW_COST_CONTRIBUTION
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_driftw',myThid)
#endif
      call timer_start('cost_driftw        [ECCO SPIN-DOWN]', mythid)
      call cost_driftw( myiter, mytime, mythid )
      call timer_stop ('cost_driftw        [ECCO SPIN-DOWN]', mythid)
#endif
      _BARRIER

c--   Compute initial vs. final T/S deviation
#ifdef ALLOW_COST_INI_FIN
      call timer_start('cost_ini_fin       [ECCO SPIN-DOWN]', mythid)
      call cost_theta_ini_fin( myiter, mytime, mythid )
      call cost_salt_ini_fin( myiter, mytime, mythid )
      call timer_stop ('cost_ini_fin       [ECCO SPIN-DOWN]', mythid)
#endif
      _BARRIER

c--   Eddy stress penalty term
#ifdef ALLOW_COST_TAU_EDDY
      call timer_start('cost_tau_eddy      [ECCO SPIN-DOWN]', mythid)
      call cost_tau_eddy( mythid )
      call timer_stop ('cost_tau_eddy      [ECCO SPIN-DOWN]', mythid)
#endif

c--   Sum all cost function contributions.
#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_CALL('cost_final',myThid)
#endif
      call timer_start('COST_FINAL         [ECCO SPIN-DOWN]', mythid)
      call cost_final( mythid )
      call timer_stop ('COST_FINAL         [ECCO SPIN-DOWN]', mythid)

#endif /* ALLOW_COST */

      call timer_stop ('ECCO SPIN-DOWN', mythid)

#ifndef DISABLE_DEBUGMODE
      IF ( debugLevel .GE. debLevB ) 
     &    CALL DEBUG_LEAVE('THE_MAIN_LOOP',myThid)
#endif

      return
      end

