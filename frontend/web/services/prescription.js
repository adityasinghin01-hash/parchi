// Presentation fixtures copied from the supplied screen references. Not live offers.
const medicines = [
  ['atorvastatin','Atorvastatin 10 mg',false,[108,506,105,93]],
  ['metformin','Metformin 500 mg',false,[108,648,105,93]],
  ['amlodipine','Amlodipine 5 mg',true,[108,790,105,93]],
  ['pantoprazole','Pantoprazole 40 mg',false,[108,932,105,93]],
  ['paracetamol','Paracetamol 500 mg',false,[108,1074,105,93]]
].map(([id,name,limited,crop])=>({id,name,kind:'medicine',detail:'Tablet · Strip of 10',quantity:1,selected:true,limited,crop}));
const tests = [
  {id:'cbc',name:'CBC (Complete Blood Count)'},
  {id:'lipid',name:'Lipid Profile'}
].map(item=>({...item,kind:'test',detail:'Lab test',quantity:1,selected:true}));
export const sampleItems = () => structuredClone([...medicines,...tests]);
export const selectedItems = (items,kind) => items.filter(item=>item.selected&&(!kind||item.kind===kind));
export const money = value => Number.isInteger(value)?'₹'+new Intl.NumberFormat('en-IN',{maximumFractionDigits:2}).format(value/100):'—';
export const basketKey = (items,kind) => JSON.stringify(selectedItems(items,kind).map(({id,name,detail,quantity})=>({id,name,detail,quantity})).sort((a,b)=>a.id.localeCompare(b.id)));
const baseline = {medicine:basketKey(sampleItems(),'medicine'),test:basketKey(sampleItems(),'test')};
const medicineOffers = [
  {id:'apollo',name:'Apollo Pharmacy',pricePaise:34500,distance:0.8,availableCount:5,readyLabel:'Ready in 15–20 mins',readyMinutes:15,bestValue:true,crop:[48,738,117,101]},
  {id:'medplus',name:'MedPlus Pharmacy',pricePaise:32000,distance:1.2,availableCount:4,readyLabel:'Ready in 30–40 mins',readyMinutes:30,crop:[48,924,117,61]},
  {id:'apollo247',name:'Apollo 24/7',pricePaise:38000,distance:1.6,availableCount:4,missingLabel:'1 item not available',readyLabel:'Ready in 25–30 mins',readyMinutes:25,crop:[47,1108,118,101]},
  {id:'sun',name:'Sun Pharma Plus',pricePaise:36000,distance:2.1,availableCount:5,readyLabel:'Ready in 30–35 mins',readyMinutes:30,crop:[47,1294,117,111]}
].map(offer=>({...offer,kind:'medicine',requiredCount:5,sourceName:'medicine-options',area:'HSR Layout',badges:[]}));
const labOffers = [
  {id:'thyrocare',name:'Thyrocare Lab',pricePaise:48500,distance:0.8,readyLabel:'Sample collection today 4:30 pm',readyMinutes:270,bestValue:true,crop:[115,725,135,94],badges:[['home','Home sample collection','warm']]},
  {id:'lal',name:'Dr Lal PathLabs',pricePaise:52000,distance:1.4,readyLabel:'Sample collection tomorrow morning',readyMinutes:1440,crop:[114,909,127,86],badges:[['flask','Fasting required','red']]},
  {id:'metropolis',name:'Metropolis Lab',pricePaise:51000,distance:2.1,readyLabel:'Report by tomorrow',readyMinutes:1440,crop:[113,1108,133,77],badges:[['home','Home sample collection','warm']]},
  {id:'redcliffe',name:'Redcliffe Labs',pricePaise:47000,distance:1.8,readyLabel:'Sample collection today 6:00 pm',readyMinutes:360,crop:[113,1290,134,92],badges:[['calendar','Slot today','blue']]}
].map(offer=>({...offer,kind:'test',requiredCount:2,availableCount:2,sourceName:'lab-options',area:'HSR Layout'}));

export function referenceOffers(items,kind){
  const current=basketKey(items,kind)===baseline[kind];
  return structuredClone(kind==='test'?labOffers:medicineOffers).map(offer=>({...offer,reference:true,
    ...(current?{}:{pricePaise:null,availableCount:null,requiredCount:selectedItems(items,kind).length,readyLabel:'Refresh quote required',readyMinutes:null,badges:[],bestValue:false})}));
}
// Inject before app.js to integrate the reader/planner. The default does not
// upload files, run OCR, infer treatment, fetch prices or contact providers.
// read({file,signal,onProgress}) -> {items,privacy:{redacted:boolean},imageUrl?}
// compare({items,kind,area,signal}) -> Offer[]; integer paise, nullable unknowns.
export const prescriptionService=window.PARCHI_PRESCRIPTION_SERVICE||null;
