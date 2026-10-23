// Source-only presentation snapshots. Prices, quantities, care schedules and
// statuses are not live facts and are not inferred from a patient's prescription.
export const providerArt={
 apollo:['medicine-options',[48,738,117,101]],medplus:['medicine-options',[48,924,117,61]],
 thyrocare:['lab-options',[115,725,135,94]],lal:['lab-options',[114,909,127,86]],
 netmeds:['plans-list',[166,833,90,57]],pharmeasy:['plans-list',[280,846,108,34]],tata:['plans-list',[423,844,55,44]],srl:['plans-list',[512,841,83,51]],
 metropolis:['lab-options',[113,1108,133,77]]
};
export const plansFixture=[
 {id:'plan-1',number:1,total:124800,referenceTotal:146000,saving:14,sellerCount:2,labCount:1,medicineCount:8,testCount:3,trips:2,ready:'Today, 4:30 PM',readyRank:1,bestRank:2,providers:['apollo','medplus','thyrocare'],cheapest:true},
 {id:'plan-2',number:2,total:130200,referenceTotal:154000,saving:16,sellerCount:3,labCount:1,medicineCount:8,testCount:3,trips:3,ready:'Tomorrow, 9:00 AM',readyRank:3,bestRank:3,providers:['netmeds','pharmeasy','tata','srl']},
 {id:'plan-3',number:3,total:141800,referenceTotal:168000,saving:15,sellerCount:1,labCount:1,medicineCount:8,testCount:3,trips:1,ready:'Today, 6:00 PM',readyRank:2,bestRank:1,providers:['apollo','lal']}
];
export const planReviewFixture=[
 {id:'apollo',name:'Apollo Pharmacy',kind:'medicine',count:4,total:52000,summary:'Paracetamol 500 mg　 |　 Amlodipine 5 mg　 |　 Atorvastatin 10 mg　 +1 more',method:'Home delivery',time:'3:12 PM'},
 {id:'medplus',name:'MedPlus',kind:'medicine',count:3,total:26000,summary:'Metformin 500 mg　 |　 Vitamin D3　 |　 +1 more',method:'Store pickup',time:'3:13 PM'},
 {id:'thyrocare',name:'Thyrocare Diagnostics',kind:'test',count:3,total:41800,summary:'CBC (Complete Blood Count)　 |　 T3　 |　 Lipid Profile',method:'Home collection',time:'3:14 PM'}
];
export const checkoutFixture=[
 {id:'apollo',name:'Apollo Pharmacy',kind:'Pharmacy',distance:'0.8 km',ready:'~30 mins',estimate:83000,items:[{id:'paracetamol',name:'Paracetamol 500 mg (10 tabs)',price:2500},{id:'amlodipine',name:'Amlodipine 5 mg (10 tabs)',price:6000},{id:'metformin',name:'Metformin 500 mg (10 tabs)',price:4500}]},
 {id:'medplus',name:'MedPlus Pharmacy',kind:'Pharmacy',distance:'1.2 km',ready:'~40 mins',estimate:26000,items:[{id:'medplus-metformin',name:'Metformin 500 mg',price:null},{id:'vitamin-d3',name:'Vitamin D3',price:null},{id:'unlisted',name:'One medicine not named in the reference',price:null}]},
 {id:'thyrocare',name:'Thyrocare Diagnostics',kind:'Lab',distance:'1.1 km',ready:'Today, 4:30 PM',estimate:41800,items:[{id:'cbc',name:'CBC (Complete Blood Count)',price:null},{id:'t3',name:'T3',price:null},{id:'lipid',name:'Lipid Profile',price:null}]}
];
export const trackingFixture=[
 {id:'apollo',name:'Apollo Pharmacy',kind:'medicine',distance:'0.8 km',status:'Delivered',tone:'green',steps:[['Order confirmed','10:12 AM','done'],['Preparing your order','10:25 AM','done'],['Out for delivery','11:05 AM','done'],['Delivered','11:28 AM','done']],items:['Paracetamol 500 mg (10 tabs)','Amlodipine 5 mg (10 tabs)','Metformin 500 mg (10 tabs)']},
 {id:'medplus',name:'MedPlus Pharmacy',kind:'medicine',distance:'1.2 km',status:'On the way',tone:'warm',steps:[['Order confirmed','10:15 AM','done'],['Preparing your order','10:40 AM','done'],['Out for delivery','11:20 AM','current'],['Expected delivery','12:00–12:30 PM','pending']],items:['Two medicine items; names not supplied in this tracking reference']},
 {id:'thyrocare',name:'Thyrocare Diagnostics',kind:'test',distance:'1.1 km',status:'Today 4:30 PM',tone:'warm',steps:[['Slot confirmed','Today, 10:18 AM','done'],['Upcoming test','Today, 4:30 PM','current'],['Sample collection','Pending','pending'],['Report ready','By tomorrow, 10:00 AM','pending']],items:['Lab test details await the provider record']}
];
export const careFixture=[
 {id:'paracetamol',name:'Paracetamol 500 mg',detail:'1 tablet · After breakfast',time:'8:00 AM',status:'Taken'},
 {id:'amlodipine',name:'Amlodipine 5 mg',detail:'1 tablet · After breakfast',time:'8:00 AM',status:'Taken'},
 {id:'metformin',name:'Metformin 500 mg',detail:'1 tablet · After lunch',time:'1:00 PM',status:'Due'},
 {id:'atorvastatin',name:'Atorvastatin 10 mg',detail:'1 tablet · After dinner',time:'8:00 PM',status:'Upcoming'}
];
export const passFixture={id:'PRC-8294-5617',patient:'Aarav Mehta',date:'10 Oct 2026',area:'HSR Layout, Bengaluru',patientConfirmed:true,
 medicines:['Paracetamol 500 mg','Amlodipine 5 mg','Metformin 500 mg','Atorvastatin 10 mg'].map(name=>({name,form:'Tablet',quantity:'10 tablets'})),
 tests:[{name:'Complete Blood Count (CBC)',quantity:'1 test'},{name:'Thyroid Profile (T3, T4, TSH)',quantity:'1 test'}]};
