C $Header: /u/gcmpack/MITgcm_contrib/verification_other/shelfice_remeshing/code/SHELFICE.h,v 1.1 2015/12/11 19:48:31 dgoldberg Exp $
C $Name:  $

#ifdef ALLOW_SHELFICE

CBOP
C !ROUTINE: SHELFICE.h

C !DESCRIPTION: \bv
C     *==========================================================*
C     | SHELFICE.h
C     | o Basic header thermodnynamic shelf ice package.
C     |   Contains all SHELFICE field declarations.
C     *==========================================================*

C-----------------------------------------------------------------------
C
C--   Constants that can be set in data.shelfice
C     SHELFICEtopoFile         :: File containing the topography of the
C                                 shelfice draught (unit=m)
C     SHELFICEGroundTopoFile   :: File containing the topography of "grounded"
c                                 ice (unit=m)
C     SHELFICEmassFile         :: name of shelfice Mass file
C     SHELFICEGroundInitFile   :: name of GroundingMass file, equivalent to justC                                 float ice at GroundTopo level 
C     SHELFICEloadAnomalyFile  :: name of shelfice load anomaly file
C     SHELFICEMassDynTendFile  :: file name for other mass tendency
C                                 (e.g. dynamics)
C     useISOMIPTD              :: use simple ISOMIP thermodynamics, def: F
C     SHELFICEconserve         :: use conservative form of H&O-thermodynamics
C                                 following Jenkins et al. (2001, JPO), def: F
C     SHELFICEMassStepping     :: flag to step forward ice shelf mass/thickness
C                                 accounts for melting/freezing & dynamics
C                                 (from file or from coupling), def: F
C     SHELFICEDynMassOnly      :: step ice mass ONLY with Shelficemassdyntendency
C                                 (not melting/freezing) def: F
C     SHELFICEboundaryLayer    :: turn on vertical merging of cells to for a
C                                 boundary layer of drF thickness, def: F
C     SHELFICEthickboundaryLayer
C                              :: similar to boundary layer but allow for a thicker
C                                 layer, encompassing 3 cells in vertical, def: F
C     SHELFICErealFWflux       :: ensure vert advective flux at bdry uses top cell
C                                 value rather than "boundary layer" value   F
C     SHELFICEadvDiffHeatFlux  :: use advective-diffusive heat flux into the
C                                 ice shelf instead of default diffusive heat
C                                 flux, see Holland and Jenkins (1999),
C                                 eq.21,22,26,31; def: F
C     SHELFICEheatTransCoeff   :: constant heat transfer coefficient that
C                                 determines heat flux into shelfice
C                                 (def: 1e-4 m/s)
C     SHELFICEsaltTransCoeff   :: constant salinity transfer coefficient that
C                                 determines salt flux into shelfice
C                                 (def: 5.05e-3 * 1e-4 m/s)
C     -----------------------------------------------------------------------
C     SHELFICEuseGammaFrict    :: use velocity dependent exchange coefficients,
C                                 see Holland and Jenkins (1999), eq.11-18,
C                                 with the following parameters (def: F):
C     shiCdrag                 :: quadratic drag coefficient to compute uStar
C                                 (def: 0.0015)
C     shiZetaN                 :: ??? (def: 0.052)
C     shiRc                    :: ??? (not used, def: 0.2)
C     shiPrandtl, shiSchmidt   :: constant Prandtl (13.8) and Schmidt (2432.0)
C                                 numbers used to compute gammaTurb
C     shiKinVisc               :: constant kinetic viscosity used to compute
C                                 gammaTurb (def: 1.95e-5)
C     SHELFICERemeshFrequency  :: Frequency that size of etaN is checked to 
C                                 trigger remesh
C     SHELFICESplitThreshold   :: Max size of etaN allowed before a remesh
C     SHELFICEMergeThreshold   :: Min size of etaN allowed before a remesh
C     -----------------------------------------------------------------------
C     SHELFICEDragLinear       :: linear drag at bottom shelfice (1/s)
C     SHELFICEDragQuadratic    :: quadratic drag at bottom shelfice (default
C                                 = shiCdrag or bottomDragQuadratic)
C     no_slip_shelfice         :: set slip conditions for shelfice separately,
C                                 (by default the same as no_slip_bottom, but
C                                 really should be false when there is linear
C                                 or quadratic drag)
C     SHELFICElatentHeat       :: latent heat of fusion (def: 334000 J/kg)
C     SHELFICEwriteState       :: enable output
C     SHELFICEHeatCapacity_Cp  :: heat capacity of ice shelf (def: 2000 J/K/kg)
C     rhoShelfIce              :: density of ice shelf (def: 917.0 kg/m^3)
C
C     SHELFICE_dump_mnc        :: use netcdf for snapshot output
C     SHELFICE_tave_mnc        :: use netcdf for time-averaged output
C     SHELFICE_dumpFreq        :: analoguous to dumpFreq (= default)
C     SHELFICE_taveFreq        :: analoguous to taveFreq (= default)
C
C--   Fields
C     ktopC                  :: index of the top "wet cell" (2D)
C     R_shelfIce             :: shelfice topography [m]
C     R_Grounding            :: "grounded" ice topography [m]
C     shelficeMassInit       :: ice-shelf mass (per unit area) (kg/m^2)
C     shelficeMass           :: ice-shelf mass (per unit area) (kg/m^2)
C     shelfIceMassDynTendency :: other mass balance tendency  (kg/m^2/s)
C                            ::  (e.g., from dynamics)
C     shelficeLoadAnomaly    :: pressure load anomaly of shelfice (Pa)
C     shelficeHeatFlux       :: upward heat flux (W/m^2)
C     shelficeFreshWaterFlux :: upward fresh water flux (virt. salt flux)
C                               (kg/m^2/s)
C     shelficeForcingT       :: analogue of surfaceForcingT
C                               units are  r_unit.Kelvin/s (=Kelvin.m/s if r=z)
C     shelficeForcingS       :: analogue of surfaceForcingS
C                               units are  r_unit.psu/s (=psu.m/s if r=z)
C-----------------------------------------------------------------------
C \ev
CEOP

      COMMON /SHELFICE_PARMS_I/  kTopC,
     &     SHELFICEselectDragQuadr
      INTEGER kTopC (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      INTEGER SHELFICEselectDragQuadr

      COMMON /SHELFICE_PARMS_R/
     &     SHELFICE_dumpFreq, SHELFICE_taveFreq,
     &     SHELFICEheatTransCoeff, SHELFICEsaltTransCoeff,
     &     rhoShelfice, SHELFICEkappa,
     &     SHELFICElatentHeat, 
     &     SHELFICEheatCapacity_Cp,
     &     SHELFICEthetaSurface,
     &     SHELFICEDragLinear, SHELFICEDragQuadratic,
     &     shiCdrag, shiZetaN, shiRc,
     &     shiPrandtl, shiSchmidt, shiKinVisc,
     &     SHELFICERemeshFrequency,
     &     SHELFICESplitThreshold,
     &     SHELFICEMergeThreshold,
     &     SHELFICEGroundW,
     &     SHELFICEGroundC
      _RL SHELFICE_dumpFreq, SHELFICE_taveFreq
      _RL SHELFICEheatTransCoeff
      _RL SHELFICEsaltTransCoeff
      _RL SHELFICElatentHeat
      _RL SHELFICEheatCapacity_Cp
      _RL rhoShelfice
      _RL SHELFICEkappa
      _RL SHELFICEDragLinear
      _RL SHELFICEDragQuadratic, SHELFICEMergeThreshold
      _RL SHELFICEthetaSurface, SHELFICESplitThreshold
      _RL shiCdrag, shiZetaN, shiRc, SHELFICERemeshFrequency
      _RL shiPrandtl, shiSchmidt, shiKinVisc
      _RL SHELFICEGroundW, SHELFICEGroundC
      COMMON /SHELFICE_FIELDS_RL/
     &     shelficeMass, shelficeMassInit, shelficeGroundInit,
     &     shelficeLoadAnomaly,
     &     shelficeForcingT, shelficeForcingS,
     &     shiTransCoeffT, shiTransCoeffS 
      _RL shelficeMass          (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL shelficeMassInit      (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL shelficeGroundInit    (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL shelficeLoadAnomaly   (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL shelficeForcingT      (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL shelficeForcingS      (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL shiTransCoeffT        (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL shiTransCoeffS        (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
     
      COMMON /SHELFICE_FIELDS_RS/
     &     R_shelfIce, 
     &     R_Grounding, 
     &     shelficeHeatFlux,
     &     shelfIceFreshWaterFlux,
     &     shelfIceMassDynTendency,
      _RS R_shelfIce            (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS R_Grounding           (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS shelficeHeatFlux      (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS shelficeFreshWaterFlux(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RS
     &   shelfIceMassDynTendency(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)

#ifdef ALLOW_SHIFWFLX_CONTROL
      COMMON /SHELFICE_MASKS_CTRL/ maskSHI
      _RS maskSHI  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
#endif /* ALLOW_SHIFWFLX_CONTROL */

      LOGICAL SHELFICEisOn
      LOGICAL useISOMIPTD
      LOGICAL SHELFICEconserve
      LOGICAL SHELFICEboundaryLayer
      LOGICAL SHELFICEthickBoundaryLayer
      LOGICAL SHELFICErealFWflux
      LOGICAL no_slip_shelfice
      LOGICAL SHELFICEwriteState
      LOGICAL SHELFICE_dump_mdsio
      LOGICAL SHELFICE_tave_mdsio
      LOGICAL SHELFICE_dump_mnc
      LOGICAL SHELFICE_tave_mnc
      LOGICAL SHELFICEadvDiffHeatFlux
      LOGICAL SHELFICEuseGammaFrict
      LOGICAL SHELFICEMassStepping
      LOGICAL SHELFICEDynMassOnly
      COMMON /SHELFICE_PARMS_L/
     &     SHELFICEisOn,
     &     useISOMIPTD,
     &     SHELFICEconserve,
     &     SHELFICErealFWflux,
     &     SHELFICEboundaryLayer,
     &     SHELFICEthickBoundaryLayer,
     &     no_slip_shelfice,
     &     SHELFICEwriteState,
     &     SHELFICE_dump_mdsio,
     &     SHELFICE_tave_mdsio,
     &     SHELFICE_dump_mnc,
     &     SHELFICE_tave_mnc,
     &     SHELFICEadvDiffHeatFlux,
     &     SHELFICEuseGammaFrict,
     &     SHELFICEMassStepping,
     &     SHELFICEDynMassOnly

      CHARACTER*(MAX_LEN_FNAM) SHELFICEloadAnomalyFile
      CHARACTER*(MAX_LEN_FNAM) SHELFICEmassFile
      CHARACTER*(MAX_LEN_FNAM) SHELFICEGroundTopoFile
      CHARACTER*(MAX_LEN_FNAM) SHELFICEtopoFile
      CHARACTER*(MAX_LEN_FNAM) SHELFICEMassDynTendFile
      CHARACTER*(MAX_LEN_FNAM) SHELFICEGroundInitFile
      CHARACTER*(MAX_LEN_FNAM) SHELFICETransCoeffTFile 


      COMMON /SHELFICE_PARM_C/
     &     SHELFICEloadAnomalyFile,
     &     SHELFICEmassFile,
     &     SHELFICEtopoFile,
     &     SHELFICEGroundTopoFile,
     &     SHELFICEMassDynTendFile,
     &     SHELFICEGroundInitFile,
     &     SHELFICETransCoeffTFile 

#endif /* ALLOW_SHELFICE */