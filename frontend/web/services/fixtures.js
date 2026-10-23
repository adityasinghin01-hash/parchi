// Reference-only fixture data. These are not real accounts, orders or service availability.
export const homeFixture = {
  source: 'reference-demo', area: 'Meerut', serviceLabel: 'Nearby chemists and labs available',
  activeOrder: { id:'demo-order', etaMinutes:28, seller:'MedPlus Pharmacy', itemCount:3, phase:'Out for delivery' },
  recent: [
    {id:'sharma',name:'Dr. Sharma',summary:'3 medicines, 1 test',date:'22 Oct',status:'In Progress',tone:'amber',icon:'rx'},
    {id:'citylab',name:'City Lab',summary:'2 tests',date:'18 Oct',status:'Completed',tone:'green',icon:'flask'},
    {id:'mehta',name:'Dr. Mehta',summary:'4 medicines',date:'12 Oct',status:'Delivered',tone:'tan',icon:'rx'}
  ]
};
export const savedAreasFixture = [
  {id:'home',label:'Home',detail:'HSR Layout, Bengaluru 560102',city:'Bengaluru',icon:'home'},
  {id:'work',label:'Work',detail:'Koramangala, Bengaluru 560034',city:'Bengaluru',icon:'briefcase'}
];
export const recentAreasFixture = [
  {id:'indiranagar',label:'Indiranagar, Bengaluru 560038',city:'Bengaluru'},
  {id:'whitefield',label:'Whitefield, Bengaluru 560066',city:'Bengaluru'}
];
export const citiesFixture = [
  {id:'bengaluru',label:'Bengaluru',crop:[59,1322,142,52]},
  {id:'meerut',label:'Meerut',crop:[228,1316,137,62]},
  {id:'muradnagar',label:'Muradnagar',crop:[394,1314,142,64]},
  {id:'more',label:'More cities'}
];
export const filesFixture = [
  {id:'rx1',name:'Dr. Sharma',date:'12 Oct 2026',crop:[51,1355,123,123]},
  {id:'rx2',name:'City Clinic',date:'28 Sep 2026',crop:[221,1355,130,123]},
  {id:'rx3',name:'Diagnostic Centre',date:'14 Sep 2026',crop:[390,1355,134,123]},
  {id:'rx4',name:'Dr. Mehta',date:'10 Sep 2026',crop:[559,1355,127,123]}
];
