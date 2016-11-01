//
//  MedicationConstants.h
//  Dosecast-API
//
//  Created by Shawn Grimes on 9/12/12.
//  Copyright (c) 2012 Montuno Software, LLC. All rights reserved.
//

#ifndef Dosecast_API_MedicationConstants_h
#define Dosecast_API_MedicationConstants_h

typedef enum {
    MedicationResultMatchBrandName=0,
    MedicationResultMatchGenericName
} MedicationResultMatch;

typedef enum {
    MedicationSearchTypeAll=0,
    MedicationSearchTypeOTC,
    MedicationSearchTypeRX
} MedicationSearchType;


#endif
