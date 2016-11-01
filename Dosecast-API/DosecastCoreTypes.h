//
//  DosecastCoreTypes.h
//  Dosecast
//
//  Created by Jonathan Levene on 2/22/10.
//  Copyright 2010 Montuno Software. All rights reserved.
//


typedef enum {
	AccountTypeDemo	   = 0,
	AccountTypePremium = 1,
    AccountTypeSubscription
} AccountType;

// Different options for how to order drugs in the main view
typedef enum {
	DrugSortOrderByNextDoseTime = 0,
    DrugSortOrderByPerson       = 1,
    DrugSortOrderByDrugName     = 2,
    DrugSortOrderByDrugType     = 3 
} DrugSortOrder;
