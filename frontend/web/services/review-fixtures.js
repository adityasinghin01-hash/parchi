// Literal sample content from the regenerated screenshot, never inferred doses
// or test preparation rules. These values do not describe a real patient's care.
export function sampleReviewItems(){return [
  {id:'amlodipine',name:'Amlodipine 5 mg',kind:'medicine',form:'Tablet',schedule:'1 OD × 30 days',detail:'Tablet · prescription reference',matchStatus:'exact',iconTone:'rose'},
  {id:'metformin',name:'Metformin 500 mg',kind:'medicine',form:'Tablet',schedule:'1 BD × 30 days',detail:'Tablet · prescription reference',matchStatus:'exact',iconTone:'peach'},
  {id:'atorvastatin',name:'Atorvastatin 10 mg',kind:'medicine',form:'Capsule',schedule:'1 OD × 30 days',detail:'Capsule · prescription reference',matchStatus:'exact',iconTone:'blue'},
  {id:'cbc',name:'CBC (Complete Blood Count)',kind:'test',form:'Blood Test',detail:'Blood test · prescription reference',badge:'No fasting',iconTone:'rose'},
  {id:'unclear-medicine',name:'Medicine name unclear',kind:'medicine',detail:'Form, strength and quantity require confirmation',unresolved:true,reviewNumber:1,reviewTitle:'Medicine name unclear',reviewReason:'Handwriting unclear',candidates:['Telma 40','Telma 80','Telsar 40'],sourceCrop:[125,1088,156,121]},
  {id:'unclear-test',name:'Test name unclear',kind:'test',detail:'Test variant requires confirmation',unresolved:true,reviewNumber:2,reviewTitle:'Test name unclear',reviewReason:'Could be multiple tests',candidates:['T3','Free T3','Total T3'],sourceCrop:[125,1265,156,120]}
].map(item=>({...item,quantity:1,selected:!item.unresolved}));}
