MODULE LB_PROCEDURES
    USE RCIMAGEIO

    IMPLICIT NONE
    
    TYPE BOUNDARY_CONDITIONS
        LOGICAL :: PERIODIC_X, PERIODIC_Y, FIXED_X, FIXED_Y
    END TYPE

CONTAINS
!-------------------------------------------------------------------------------
SUBROUTINE ALLOCATE_DATA(DOMAIN, DOMAIN_2, SOLID_VOXELS, B_CONDS, IS_SOLID,&
									 M, N, NUM_SOLIDS, INPUT, RELAX, END_TIME)
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(OUT) :: DOMAIN, DOMAIN_2
    INTEGER, ALLOCATABLE, DIMENSION(:,:), INTENT(OUT) :: SOLID_VOXELS
    TYPE (BOUNDARY_CONDITIONS), INTENT(OUT) :: B_CONDS
    LOGICAL, ALLOCATABLE, DIMENSION(:,:), INTENT(OUT) :: IS_SOLID
    INTEGER, INTENT(OUT) :: M, N, NUM_SOLIDS, END_TIME
    TYPE(RGBIMAGE), INTENT(OUT) :: INPUT
    DOUBLE PRECISION, INTENT(OUT) :: RELAX
    
    INTEGER :: ROW, COL
    OPEN(UNIT=1,FILE='geometry.ppm',STATUS='OLD')
    CALL READ_PPM(1, INPUT)
    CLOSE(UNIT=1)
    
    N = INPUT%WIDTH
    M = INPUT%HEIGHT

!   ALLOCATE THE SIMULATION DOMAIN INCLUDING GHOST POINTS
    ALLOCATE(DOMAIN(0:8,0:M+1,0:N+1))
    ALLOCATE(DOMAIN_2(0:8,0:M+1,0:N+1))
    ALLOCATE(IS_SOLID(M,N))

    NUM_SOLIDS = 0
!   SEARCH FOR AND COUNT ALL ELEMENTS FROM THE INPUT GEOMETRY
    DO COL = 1, N
        DO ROW = 1, M
        	IS_SOLID(ROW,COL) = .FALSE.
            IF (INPUT%RED(COL,ROW) == 0 .AND.                                &
                INPUT%GREEN(COL,ROW) == 0 .AND.                              &
                INPUT%BLUE(COL,ROW) == 0 ) THEN
                
                NUM_SOLIDS = NUM_SOLIDS + 1
                IS_SOLID(ROW,COL) = .TRUE.
            END IF
        END DO
    END DO
    PRINT *, NUM_SOLIDS
!   ALLOCATE THE INDEX OF ALL SOLID ELEMENTS IN THE SIMULATION
    ALLOCATE(SOLID_VOXELS(NUM_SOLIDS,2))

!   SEARCH FOR AND STORE COORDINATES OF ALL ELEMENTS FROM THE INPUT GEOMETRY    
    NUM_SOLIDS = 0         
    DO COL = 1, N
        DO ROW = 1, M
            IF (IS_SOLID(ROW,COL)) THEN

                NUM_SOLIDS = NUM_SOLIDS + 1                             
                SOLID_VOXELS(NUM_SOLIDS,1) = ROW
                SOLID_VOXELS(NUM_SOLIDS,2) = COL
            END IF
        END DO
    END DO

    OPEN(UNIT=1,FILE='input',STATUS='OLD')
   
!   SKIP TITLES IN INPUT FILE
    READ(UNIT=1,FMT=*)
    READ(UNIT=1,FMT=*) B_CONDS%PERIODIC_X, B_CONDS%PERIODIC_Y,				   &
    				   B_CONDS%FIXED_X, B_CONDS%FIXED_Y
    READ(UNIT=1,FMT=*)
    READ(UNIT=1,FMT=*) RELAX
    READ(UNIT=1,FMT=*)
    READ(UNIT=1,FMT=*) END_TIME
 
    CLOSE(UNIT=1)
         
END SUBROUTINE ALLOCATE_DATA
!-------------------------------------------------------------------------------
SUBROUTINE INITIALISE_VALUES(DOMAIN, DOMAIN_2, SOLID_VOXELS, NUM_SOLIDS)
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN, 	   &
    															  DOMAIN_2
    INTEGER, ALLOCATABLE, DIMENSION(:,:), INTENT(IN) :: SOLID_VOXELS
    INTEGER, INTENT(IN) :: NUM_SOLIDS
    INTEGER :: I, J
    CALL RANDOM_NUMBER(DOMAIN)
    DOMAIN = 3*(DOMAIN)

!    CALL RANDOM_NUMBER(DOMAIN(:,:,:))
!    DOMAIN = 2.0    
    DO I = 1, NUM_SOLIDS
    	DO J = 1, 9
        	DOMAIN(J,SOLID_VOXELS(I,1),SOLID_VOXELS(I,2)) = 0
        	DOMAIN_2(J,SOLID_VOXELS(I,1),SOLID_VOXELS(I,2)) = 0
        END DO
    END DO

END SUBROUTINE INITIALISE_VALUES
!-------------------------------------------------------------------------------
SUBROUTINE ACCELERATE_FLOW(DOMAIN, M, IS_SOLID)
  IMPLICIT NONE
  DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN
	INTEGER, INTENT(IN) :: M
	LOGICAL, ALLOCATABLE, DIMENSION(:,:), INTENT(IN) :: IS_SOLID
	INTEGER :: I
	DOUBLE PRECISION :: X = 1E-1
	DO I = 1, M
		IF (.NOT. IS_SOLID(I,1)) THEN
!      IF (DOMAIN(2,I,1) - X .GT. 0) THEN
!        DOMAIN(2,I,1) = DOMAIN(2,I,1) - X
!        DOMAIN(7,I,1) = DOMAIN(7,I,1) + X
!      END IF
!      IF (DOMAIN(1,I,1) - X .GT. 0) THEN
!        DOMAIN(1,I,1) = DOMAIN(1,I,1) - X
!        DOMAIN(8,I,1) = DOMAIN(8,I,1) + X
!      END IF
!      IF (DOMAIN(3,I,1) - X .GT. 0) THEN
!        DOMAIN(3,I,1) = DOMAIN(3,I,1) - X
!        DOMAIN(6,I,1) = DOMAIN(6,I,1) + X
!      END IF
			X = SUM(DOMAIN(:,I,1))
			DOMAIN(0,I,1) = X/18.0
			DOMAIN(1,I,1) = X/18.0
			DOMAIN(2,I,1) = X/18.0
			DOMAIN(3,I,1) = X/18.0
			DOMAIN(4,I,1) = X/18.0 
			DOMAIN(5,I,1) = X/18.0
			DOMAIN(6,I,1) = 3.0*X/18.0 
			DOMAIN(7,I,1) = 6.0*X/18.0
			DOMAIN(8,I,1) = 3.0*X/18.0 
		END IF
	END DO
END SUBROUTINE ACCELERATE_FLOW
!-------------------------------------------------------------------------------
SUBROUTINE ADVECTION (DOMAIN, DOMAIN_2, IS_SOLID, M, N)
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN,      &
                                                                  DOMAIN_2
    LOGICAL, ALLOCATABLE, DIMENSION(:,:), INTENT(IN) :: IS_SOLID   
    INTEGER, INTENT(IN) :: M, N    
    INTEGER :: ROW, COL

!   CURRENT VALUES IN THE DOMAIN ARE SHIFTED BY ONE. SOME OF THESE VALUES MOVE
!   INTO THE GHOSTPOINTS SURROUNDING THE DOMAIN. THEY WILL BE CAPTURED IN THE
!   'ENFORCE_BOUNDARIES()' SUBROUTINE DEPENDING ON THE BOUNDARY CONDITIONS
!   SPECIFIED IN THE INPUT
    DO COL = 1, N
        DO ROW = 1, M
        	IF(IS_SOLID(ROW,COL)) THEN
        		CYCLE
        	END IF
           	DOMAIN_2(1,ROW-1,COL-1) = DOMAIN(1,ROW,COL) 
            DOMAIN_2(2,ROW,COL-1)   = DOMAIN(2,ROW,COL) 
            DOMAIN_2(3,ROW+1,COL-1) = DOMAIN(3,ROW,COL) 
            DOMAIN_2(4,ROW-1,COL)   = DOMAIN(4,ROW,COL) 
            DOMAIN_2(5,ROW+1,COL)   = DOMAIN(5,ROW,COL) 
            DOMAIN_2(6,ROW-1,COL+1) = DOMAIN(6,ROW,COL)
            DOMAIN_2(7,ROW,COL+1)   = DOMAIN(7,ROW,COL)
            DOMAIN_2(8,ROW+1,COL+1) = DOMAIN(8,ROW,COL)     
        END DO
    END DO                                                    
END SUBROUTINE ADVECTION
!-------------------------------------------------------------------------------
SUBROUTINE REFLECTION(DOMAIN_2, SOLID_VOXELS, NUM_SOLIDS)
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN_2
    INTEGER, ALLOCATABLE, DIMENSION(:,:), INTENT(IN) :: SOLID_VOXELS
    INTEGER, INTENT(IN) :: NUM_SOLIDS   
    INTEGER :: I, ROW, COL
    
!   ALL VALUES THAT HAVE BEEN ADVECTED INTO ELEMENTS OF THE GEOMETRY ARE
!   RETURNED TO THE ELEMENT THEY CAME FROM. HOWEVER WITH OPPOSITE MOMENTA
    DO I = 1, NUM_SOLIDS
        ROW = SOLID_VOXELS(I,1)
        COL = SOLID_VOXELS(I,2)
        DOMAIN_2(8,ROW+1,COL+1) = DOMAIN_2(1,ROW,COL) 
        DOMAIN_2(7,ROW,COL+1)   = DOMAIN_2(2,ROW,COL) 
        DOMAIN_2(6,ROW-1,COL+1) = DOMAIN_2(3,ROW,COL) 
        DOMAIN_2(5,ROW+1,COL)   = DOMAIN_2(4,ROW,COL) 
        DOMAIN_2(4,ROW-1,COL)   = DOMAIN_2(5,ROW,COL) 
        DOMAIN_2(3,ROW+1,COL-1) = DOMAIN_2(6,ROW,COL)
        DOMAIN_2(2,ROW,COL-1)   = DOMAIN_2(7,ROW,COL)
        DOMAIN_2(1,ROW-1,COL-1) = DOMAIN_2(8,ROW,COL)
!        DOMAIN_2(:,ROW,COL) = 0
    END DO
END SUBROUTINE REFLECTION
!-------------------------------------------------------------------------------
SUBROUTINE ENFORCE_BOUNDARIES(DOMAIN_2, M, N, B_CONDS)
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN_2
    INTEGER, INTENT(IN) :: M, N
    TYPE (BOUNDARY_CONDITIONS), INTENT(IN) :: B_CONDS
!   CASE DISTINCTIONS ARE MADE FOR DIFFERENT BOUNDARY CONDITIONS
!   PRIMARILY FOR DEALING WITH THE CORNER CASE
!
!   BOTH SPACIAL DIMENSIONS ARE PERIODIC
    IF (B_CONDS%PERIODIC_X .AND. B_CONDS%PERIODIC_Y) THEN
        CALL PERIODIC_BOUNDARIES(DOMAIN_2, M, N) 
         
!   X DIMENSION IS PERIODIC, Y DIMENSION IS FIXED
    ELSE IF (B_CONDS%PERIODIC_X .AND. B_CONDS%FIXED_Y) THEN
        CALL PERIODIC_X(DOMAIN_2, M, N)
        
!   Y DIMENSION IS PERIODIC, X DIMENSION IS FIXED
    ELSE IF (B_CONDS%PERIODIC_Y .AND. B_CONDS%FIXED_X) THEN
        CALL PERIODIC_Y(DOMAIN_2, M, N)
        
!   NEITHER DIMENSION IS PERIODIC
    ELSE IF (B_CONDS%FIXED_X .AND. B_CONDS%FIXED_Y) THEN
        CALL SOLID_BOUNDARIES(DOMAIN_2, M, N)

!	Y DIMENSION IS FIXED        
    ELSE IF (B_CONDS%FIXED_Y) THEN
    	CALL SOLID_Y(DOMAIN_2, M, N)       
    END IF             
END SUBROUTINE ENFORCE_BOUNDARIES
!-------------------------------------------------------------------------------
SUBROUTINE UPDATE_BUFFER(DOMAIN, DOMAIN_2, TEMP)
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN,      &
                                                                  DOMAIN_2, TEMP

!   THIS SUBROUTINE IS CALLED AFTER THE 2ND BUFFER 'DOMAIN_2' HAS BEEN
!   COMPLETELY UPDATED FOR THE NEXT TIME STEP. THEN THE 1ST BUFFER 'DOMAIN' IS
!   POINTED TO THE UPDATED VALUES FOR THE NEXT ITERATION OF THE TIME LOOP             
    TEMP => DOMAIN
    DOMAIN => DOMAIN_2
    DOMAIN_2 => TEMP
END SUBROUTINE UPDATE_BUFFER
!-------------------------------------------------------------------------------
SUBROUTINE PERIODIC_BOUNDARIES(DOMAIN_2, M, N)
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN_2
    INTEGER, INTENT(IN) :: M, N    
    INTEGER :: ROW, COL
    
!   EXCHANGE CORNER GHOSTPOINTS    
    DOMAIN_2(1,M,N) = DOMAIN_2(1,0,0)
    DOMAIN_2(3,M,1) = DOMAIN_2(3,0,N+1)
    DOMAIN_2(6,1,N) = DOMAIN_2(6,M+1,0)
    DOMAIN_2(8,1,1) = DOMAIN_2(8,M+1,N+1)  
!   PERIODIC GHOSTPOINT EXCHANGE
    DO COL = 1, N
        DOMAIN_2(8,1,COL) = DOMAIN_2(8,M+1,COL)
        DOMAIN_2(5,1,COL) = DOMAIN_2(5,M+1,COL)
        DOMAIN_2(3,1,COL) = DOMAIN_2(3,M+1,COL)
        
        DOMAIN_2(6,M,COL) = DOMAIN_2(6,0,COL)
        DOMAIN_2(4,M,COL) = DOMAIN_2(4,0,COL)
        DOMAIN_2(1,M,COL) = DOMAIN_2(1,0,COL)       
    END DO     
    DO ROW = 1, M
        DOMAIN_2(8,ROW,1) = DOMAIN_2(8,ROW,N+1)
        DOMAIN_2(7,ROW,1) = DOMAIN_2(7,ROW,N+1)
        DOMAIN_2(6,ROW,1) = DOMAIN_2(6,ROW,N+1)
        
        DOMAIN_2(1,ROW,N) = DOMAIN_2(1,ROW,0)
        DOMAIN_2(2,ROW,N) = DOMAIN_2(2,ROW,0)
        DOMAIN_2(3,ROW,N) = DOMAIN_2(3,ROW,0)      
    END DO     
END SUBROUTINE PERIODIC_BOUNDARIES    
!-------------------------------------------------------------------------------
SUBROUTINE PERIODIC_X(DOMAIN_2, M, N)   
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN_2
    INTEGER, INTENT(IN) :: M, N    
    INTEGER :: ROW, COL
!   CORNERS ARE SOLID

!   PERIODIC GHOSTPOINT EXCHANGE
    DO ROW = 1, M
        DOMAIN_2(8,ROW,1) = DOMAIN_2(8,ROW,N+1)
        DOMAIN_2(7,ROW,1) = DOMAIN_2(7,ROW,N+1)
        DOMAIN_2(6,ROW,1) = DOMAIN_2(6,ROW,N+1)
        
        DOMAIN_2(1,ROW,N) = DOMAIN_2(1,ROW,0)
        DOMAIN_2(2,ROW,N) = DOMAIN_2(2,ROW,0)
        DOMAIN_2(3,ROW,N) = DOMAIN_2(3,ROW,0)       
    END DO
   
!   WALL INTERACTION       
    DO COL = 1, N
        DOMAIN_2(8,1,COL) = DOMAIN_2(1,0,COL-1)
        DOMAIN_2(5,1,COL) = DOMAIN_2(4,0,COL)
        DOMAIN_2(3,1,COL) = DOMAIN_2(6,0,COL+1)
        
        DOMAIN_2(6,M,COL) = DOMAIN_2(3,M+1,COL-1)
        DOMAIN_2(4,M,COL) = DOMAIN_2(5,M+1,COL)
        DOMAIN_2(1,M,COL) = DOMAIN_2(8,M+1,COL+1)       
    END DO    
END SUBROUTINE PERIODIC_X    
!-------------------------------------------------------------------------------
SUBROUTINE PERIODIC_Y(DOMAIN_2, M, N)   
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN_2
    INTEGER, INTENT(IN) :: M, N    
    INTEGER :: ROW, COL
!   CORNERS ARE SOLID
 
!   PERIODIC GHOSTPOINT EXCHANGE
    DO COL = 1, N
        DOMAIN_2(8,1,COL) = DOMAIN_2(8,M+1,COL)
        DOMAIN_2(5,1,COL) = DOMAIN_2(5,M+1,COL)
        DOMAIN_2(3,1,COL) = DOMAIN_2(3,M+1,COL)
        
        DOMAIN_2(6,M,COL) = DOMAIN_2(6,0,COL)
        DOMAIN_2(4,M,COL) = DOMAIN_2(4,0,COL)
        DOMAIN_2(1,M,COL) = DOMAIN_2(1,0,COL)       
    END DO 

!   WALL INTERACTION
    DO ROW = 1, M
        DOMAIN_2(6,ROW,1) = DOMAIN_2(3,ROW+1,0)
        DOMAIN_2(7,ROW,1) = DOMAIN_2(2,ROW,0)
        DOMAIN_2(8,ROW,1) = DOMAIN_2(1,ROW-1,0)
        
        DOMAIN_2(1,ROW,N) = DOMAIN_2(8,ROW+1,N+1)
        DOMAIN_2(2,ROW,N) = DOMAIN_2(7,ROW,N+1)         
        DOMAIN_2(3,ROW,N) = DOMAIN_2(6,ROW-1,N+1)       
    END DO 
END SUBROUTINE PERIODIC_Y     
!-------------------------------------------------------------------------------
SUBROUTINE SOLID_BOUNDARIES(DOMAIN_2, M, N)   
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN_2
    INTEGER, INTENT(IN) :: M, N    
    INTEGER :: ROW, COL
 
!   WALL INTERACTION
    DO COL = 1, N
        DOMAIN_2(8,1,COL) = DOMAIN_2(1,0,COL-1)
        DOMAIN_2(5,1,COL) = DOMAIN_2(4,0,COL)
        DOMAIN_2(3,1,COL) = DOMAIN_2(6,0,COL+1)
        
        DOMAIN_2(6,M,COL) = DOMAIN_2(3,M+1,COL-1)
        DOMAIN_2(4,M,COL) = DOMAIN_2(5,M+1,COL)
        DOMAIN_2(1,M,COL) = DOMAIN_2(8,M+1,COL+1)       
    END DO
    DO ROW = 1, M
        DOMAIN_2(6,ROW,1) = DOMAIN_2(3,ROW+1,0)
        DOMAIN_2(7,ROW,1) = DOMAIN_2(2,ROW,0)
        DOMAIN_2(8,ROW,1) = DOMAIN_2(1,ROW-1,0)
        
        DOMAIN_2(1,ROW,N) = DOMAIN_2(8,ROW+1,N+1)
        DOMAIN_2(2,ROW,N) = DOMAIN_2(7,ROW,N+1)         
        DOMAIN_2(3,ROW,N) = DOMAIN_2(6,ROW-1,N+1)       
    END DO    
    
    
END SUBROUTINE SOLID_BOUNDARIES 
!-------------------------------------------------------------------------------
SUBROUTINE SOLID_Y(DOMAIN_2, M, N) 
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN_2
    INTEGER, INTENT(IN) :: M, N    
    INTEGER :: ROW, COL    
    DO ROW = 1, M
        DOMAIN_2(6,ROW,1) = DOMAIN_2(3,ROW+1,0)
        DOMAIN_2(7,ROW,1) = DOMAIN_2(2,ROW,0)
        DOMAIN_2(8,ROW,1) = DOMAIN_2(1,ROW-1,0)
        
        DOMAIN_2(1,ROW,N) = DOMAIN_2(8,ROW+1,N+1)
        DOMAIN_2(2,ROW,N) = DOMAIN_2(7,ROW,N+1)         
        DOMAIN_2(3,ROW,N) = DOMAIN_2(6,ROW-1,N+1)       
    END DO 
END SUBROUTINE SOLID_Y
!-------------------------------------------------------------------------------
SUBROUTINE COLLISION(DOMAIN, IS_SOLID, M, N, RELAX)
	IMPLICIT NONE
	DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(INOUT) :: DOMAIN
	LOGICAL, ALLOCATABLE, DIMENSION(:,:), INTENT(IN) :: IS_SOLID
    INTEGER, INTENT(IN) :: M, N 
    DOUBLE PRECISION, INTENT(IN) :: RELAX
    
	DOUBLE PRECISION, DIMENSION(0:8) :: TP, EQUI
	DOUBLE PRECISION :: VEL_X, VEL_Y, DENSITY, CS = 1.0/3.0
	DOUBLE PRECISION :: COMMON_VAL, DENOM, THREE
	INTEGER :: ROW, COL, I

	TP(0) = 4.0/9.0
	TP(1) = 1.0/36.0
	TP(2) = 1.0/9.0
	TP(3) = 1.0/36.0
	TP(4) = 1.0/9.0
	TP(5) = 1.0/9.0
	TP(6) = 1.0/36.0
	TP(7) = 1.0/9.0
	TP(8) = 1.0/36.0
	
	DENOM = 1.0/(2*CS*CS)
	THREE = 1.0/CS

	DO COL = 1, N
		DO ROW = 1, M
			IF(IS_SOLID(ROW,COL)) THEN
				CYCLE
			END IF
			DENSITY = SUM(DOMAIN(:,ROW,COL))
			VEL_X = (-DOMAIN(1,ROW,COL)-DOMAIN(2,ROW,COL)-DOMAIN(3,ROW,COL)    &
					+ DOMAIN(6,ROW,COL)+DOMAIN(7,ROW,COL)+DOMAIN(8,ROW,COL))   &
					/ DENSITY
			VEL_Y = (DOMAIN(1,ROW,COL)-DOMAIN(3,ROW,COL)+DOMAIN(4,ROW,COL)     &
					-DOMAIN(5,ROW,COL)+DOMAIN(6,ROW,COL)-DOMAIN(8,ROW,COL))    &
					/ DENSITY
			
			COMMON_VAL = - (VEL_X*VEL_X + VEL_Y*VEL_Y)*THREE*0.5
					
			EQUI(0) = TP(0)*DENSITY*(1 + COMMON_VAL)
!									-(VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))
			EQUI(1) = TP(1)*DENSITY*(1 + ((-VEL_X + VEL_Y)*THREE)              &
									+ (-VEL_X+VEL_Y)*(-VEL_X+VEL_Y)*DENOM  &
									+ COMMON_VAL)
!									- (VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))
			EQUI(2) = TP(2)*DENSITY*(1 + (-VEL_X*THREE)+ (VEL_X*VEL_X)*DENOM  &
									+ COMMON_VAL)
!									- (VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))
			EQUI(3) = TP(3)*DENSITY*(1 + ((-VEL_X - VEL_Y)*THREE)                 &
									+ (-VEL_X-VEL_Y)*(-VEL_X-VEL_Y)*DENOM  &
									+ COMMON_VAL)
!									- (VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))
			
			EQUI(4) = TP(4)*DENSITY*(1 + ((VEL_Y)*THREE)+ (VEL_Y*VEL_Y)*DENOM &
!									- (VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))
									+ COMMON_VAL)			
			EQUI(5) = TP(5)*DENSITY*(1 + (-VEL_Y*THREE)+ (VEL_Y*VEL_Y)*DENOM  &
									+ COMMON_VAL)
!									- (VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))	
			EQUI(6) = TP(6)*DENSITY*(1 + ((VEL_X + VEL_Y)*THREE)                  &
									+ (VEL_X+VEL_Y)*(VEL_X+VEL_Y)*DENOM    &
									+ COMMON_VAL)
!									- (VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))	
			EQUI(7) = TP(7)*DENSITY*(1 + (VEL_X*THREE)	+ (VEL_X*VEL_X)*DENOM  &
									+ COMMON_VAL)
!									- (VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))
			EQUI(8) = TP(8)*DENSITY*(1 + ((VEL_X - VEL_Y)*THREE)                  &
									+ (VEL_X-VEL_Y)*(VEL_X-VEL_Y)*DENOM    &
									+ COMMON_VAL)
!									- (VEL_X*VEL_X + VEL_Y*VEL_Y)/(2*CS))
			DO I = 0, 8
				!DO WHILE (DOMAIN(I,ROW,COL) +						   		   &
				!		  EFF_OMEGA*(EQUI(I) - DOMAIN(I,ROW,COL)) < 0 		   &
				!		  .AND. EFF_OMEGA > 1E-2)
				!	EFF_OMEGA = EFF_OMEGA / 2.0
				!END DO
				DOMAIN(I,ROW,COL) = DOMAIN(I,ROW,COL) +						   &
				RELAX*(EQUI(I) - DOMAIN(I,ROW,COL))
				!EFF_OMEGA = RELAX
				IF (DOMAIN(I,ROW,COL) < 0) THEN
					DOMAIN(I,ROW,COL) = 0
				END IF
			END DO
			
		
	
		END DO
	END DO

END SUBROUTINE COLLISION
!-------------------------------------------------------------------------------
SUBROUTINE PRINT_DENSITY(DOMAIN, IS_SOLID, M, N, FILE_NUMBER, DENSITY_IMAGE)
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(IN) :: DOMAIN
	LOGICAL, ALLOCATABLE, DIMENSION(:,:), INTENT(IN) :: IS_SOLID    
    INTEGER, INTENT(IN) :: M, N, FILE_NUMBER    
    TYPE(RGBIMAGE), INTENT(OUT) :: DENSITY_IMAGE
    DOUBLE PRECISION, DIMENSION(M,N) :: DENSITY
    INTEGER :: ROW, COL, TEMP_1, TEMP_2
    DOUBLE PRECISION :: INTERPOLANT, MAXIMUM = 0
    CHARACTER(LEN=32) :: FILENAME
    
    
    DO COL = 1, N
        DO ROW = 1, M  
            DENSITY(ROW,COL) = SUM(DOMAIN(:,ROW,COL))
            IF (DENSITY(ROW,COL) > MAXIMUM) THEN
                MAXIMUM = DENSITY(ROW,COL)
            END IF   
        END DO
    END DO 

    DO ROW = 1, M 
   		 DO COL = 1, N
            INTERPOLANT = (EXP(-(DENSITY(ROW,COL)/7.0)))*5
            TEMP_1 = FLOOR(INTERPOLANT)
            TEMP_2 = FLOOR(255*(INTERPOLANT-TEMP_1))
            SELECT CASE (TEMP_1)
               CASE (0)
					          DENSITY_IMAGE%RED(COL,ROW) = 255
                    DENSITY_IMAGE%GREEN(COL,ROW) = TEMP_2
                    DENSITY_IMAGE%BLUE(COL,ROW) = 0
               CASE (1)
                    DENSITY_IMAGE%RED(COL,ROW) = 255 - TEMP_2
                    DENSITY_IMAGE%GREEN(COL,ROW) = 255
                    DENSITY_IMAGE%BLUE(COL,ROW) = 0
               CASE (2)
                    DENSITY_IMAGE%RED(COL,ROW) = 0
                    DENSITY_IMAGE%GREEN(COL,ROW) = 255
                    DENSITY_IMAGE%BLUE(COL,ROW) = TEMP_2
               CASE (3)
                    DENSITY_IMAGE%RED(COL,ROW) = 0
                    DENSITY_IMAGE%GREEN(COL,ROW) = 255 - TEMP_2
                    DENSITY_IMAGE%BLUE(COL,ROW) = 255
               CASE (4)
                    DENSITY_IMAGE%RED(COL,ROW) = TEMP_2
                    DENSITY_IMAGE%GREEN(COL,ROW) = 0
                    DENSITY_IMAGE%BLUE(COL,ROW) = 255
               CASE (5)
                    DENSITY_IMAGE%RED(COL,ROW) = 255
                    DENSITY_IMAGE%GREEN(COL,ROW) = 0
                    DENSITY_IMAGE%BLUE(COL,ROW) = 255
            END SELECT
			IF(IS_SOLID(ROW,COL)) THEN
			        DENSITY_IMAGE%RED(COL,ROW) = 0
                    DENSITY_IMAGE%GREEN(COL,ROW) = 0
                    DENSITY_IMAGE%BLUE(COL,ROW) = 0
            END IF
        END DO
    END DO 

    WRITE (FILENAME, 10) FILE_NUMBER
	10 FORMAT ('./img/density', I5.5, '.ppm')

    OPEN(UNIT=1, ACCESS='SEQUENTIAL', FILE=FILENAME)
    CALL OUTPUT_PPM(1, DENSITY_IMAGE)
    CLOSE(UNIT=1)

END SUBROUTINE PRINT_DENSITY
!-------------------------------------------------------------------------------
SUBROUTINE PRINT_VELOCITY(DOMAIN, IS_SOLID, M, N, FILE_NUMBER, VELOCITY_IMAGE)
    IMPLICIT NONE
    DOUBLE PRECISION, DIMENSION(:,:,:), POINTER, INTENT(IN) :: DOMAIN
	LOGICAL, ALLOCATABLE, DIMENSION(:,:), INTENT(IN) :: IS_SOLID    
    INTEGER, INTENT(IN) :: M, N, FILE_NUMBER    
    TYPE(RGBIMAGE), INTENT(OUT) :: VELOCITY_IMAGE
    DOUBLE PRECISION, DIMENSION(M,N) :: VELOCITY
    INTEGER :: ROW, COL, TEMP_1, TEMP_2
    DOUBLE PRECISION :: INTERPOLANT, VEL_X, VEL_Y, DENSITY, MAXIMUM = 0
    CHARACTER(LEN=32) :: FILENAME
    
    
    DO COL = 1, N
        DO ROW = 1, M  
            DENSITY = SUM(DOMAIN(:,ROW,COL))
            VEL_X = (-DOMAIN(1,ROW,COL)-DOMAIN(2,ROW,COL)-DOMAIN(3,ROW,COL)    &
					          + DOMAIN(6,ROW,COL)+DOMAIN(7,ROW,COL)+DOMAIN(8,ROW,COL))   &
					          / DENSITY
			      VEL_Y = (DOMAIN(1,ROW,COL)-DOMAIN(3,ROW,COL)+DOMAIN(4,ROW,COL)     &
					          -DOMAIN(5,ROW,COL)+DOMAIN(6,ROW,COL)-DOMAIN(8,ROW,COL))    &
					          / DENSITY
!					  IF ((VEL_X .LT. 1E-10) .AND. (VEL_Y .LT. 1E-10)) THEN
!					      VELOCITY(ROW,COL) = 0
!					  ELSE
					      VELOCITY(ROW,COL) = SQRT((VEL_X * VEL_X) + (VEL_Y * VEL_Y))
!					  END IF
!					  IF (VELOCITY(ROW,COL) < 1E-10) THEN
!					      VELOCITY(ROW,COL) = 0
!					  END IF
!					  print *,VELOCITY(ROW,COL)
!					  IF (VELOCITY(ROW,COL) > MAXIMUM) THEN
!                MAXIMUM = VELOCITY(ROW,COL)
!                print *, MAXIMUM
!            END IF
        END DO
    END DO 

    DO ROW = 1, M 
   		 DO COL = 1, N
!   		 	print *,VELOCITY(ROW,COL)
            INTERPOLANT = (EXP(-(VELOCITY(ROW,COL)*10)))*5
            TEMP_1 = FLOOR(INTERPOLANT)
            TEMP_2 = FLOOR(255*(INTERPOLANT-TEMP_1))
            SELECT CASE (TEMP_1)
               CASE (0)
					          VELOCITY_IMAGE%RED(COL,ROW) = 255
                    VELOCITY_IMAGE%GREEN(COL,ROW) = TEMP_2
                    VELOCITY_IMAGE%BLUE(COL,ROW) = 0
               CASE (1)
                    VELOCITY_IMAGE%RED(COL,ROW) = 255 - TEMP_2
                    VELOCITY_IMAGE%GREEN(COL,ROW) = 255
                    VELOCITY_IMAGE%BLUE(COL,ROW) = 0
               CASE (2)
                    VELOCITY_IMAGE%RED(COL,ROW) = 0
                    VELOCITY_IMAGE%GREEN(COL,ROW) = 255
                    VELOCITY_IMAGE%BLUE(COL,ROW) = TEMP_2
               CASE (3)
                    VELOCITY_IMAGE%RED(COL,ROW) = 0
                    VELOCITY_IMAGE%GREEN(COL,ROW) = 255 - TEMP_2
                    VELOCITY_IMAGE%BLUE(COL,ROW) = 255
               CASE (4)
                    VELOCITY_IMAGE%RED(COL,ROW) = TEMP_2
                    VELOCITY_IMAGE%GREEN(COL,ROW) = 0
                    VELOCITY_IMAGE%BLUE(COL,ROW) = 255
               CASE (5)
                    VELOCITY_IMAGE%RED(COL,ROW) = 255
                    VELOCITY_IMAGE%GREEN(COL,ROW) = 0
                    VELOCITY_IMAGE%BLUE(COL,ROW) = 255
            END SELECT
			      IF(IS_SOLID(ROW,COL)) THEN
			          VELOCITY_IMAGE%RED(COL,ROW) = 0
                VELOCITY_IMAGE%GREEN(COL,ROW) = 0
                VELOCITY_IMAGE%BLUE(COL,ROW) = 0
            END IF
        END DO
    END DO 

    WRITE (FILENAME, 10) FILE_NUMBER
	10 FORMAT ('./img/velocity', I5.5, '.ppm')

    OPEN(UNIT=1, ACCESS='SEQUENTIAL', FILE=FILENAME)
    CALL OUTPUT_PPM(1, VELOCITY_IMAGE)
    CLOSE(UNIT=1)

END SUBROUTINE PRINT_VELOCITY
!-------------------------------------------------------------------------------
END MODULE LB_PROCEDURES
