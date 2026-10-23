import { homeFixture, savedAreasFixture, recentAreasFixture } from './fixtures.js';

export class ServiceError extends Error {
  constructor(message, code = 'unavailable') { super(message); this.name = 'ServiceError'; this.code = code; }
}
const clone = data => structuredClone(data);
const normalizedPhone = value => value.replace(/[०-९]/g, digit => '०१२३४५६७८९'.indexOf(digit)).replace(/[\s-]/g,'');
export function validPhone(value) { return /^[6-9]\d{9}$/.test(normalizedPhone(value)); }

export function createDemoAdapter() {
  let challenge = null;
  let attempts = 0;
  return {
    mode:'demo',
    async startOtp(phone) {
      if (!validPhone(phone)) throw new ServiceError('Enter a valid 10-digit mobile number.','invalid_phone');
      if (challenge && Date.now() < challenge.resendAt) throw new ServiceError('Please wait before requesting another code.','rate_limited');
      challenge = {id:crypto.randomUUID(),phone:normalizedPhone(phone),expiresAt:Date.now()+120000,resendAt:Date.now()+30000,mode:'demo'};
      attempts=0; return clone(challenge);
    },
    async verifyOtp(id,code) {
      if (!challenge || id!==challenge.id) throw new ServiceError('Request a new code.','invalid_challenge');
      if (Date.now()>challenge.expiresAt) throw new ServiceError('This code has expired. Request a new one.','expired');
      if (attempts>=3) throw new ServiceError('Too many attempts. Wait, then request a new code.','too_many_attempts');
      attempts++;
      if (code!=='482931') throw new ServiceError('That code is not correct. Try again.','incorrect_code');
      const result={id:'demo-profile',phone:challenge.phone,mode:'demo'};challenge=null;return result;
    },
    async getHome() { return clone(homeFixture); },
    async getAreas() { return {saved:clone(savedAreasFixture),recent:clone(recentAreasFixture),source:'reference-demo'}; },
    async searchAreas(query) {
      return [...savedAreasFixture,...recentAreasFixture].filter(item=>(item.label+' '+(item.detail||'')).toLowerCase().includes(query.toLowerCase())).map(clone);
    },
    async confirmArea(area) { return {...clone(area),source:'manual-preview'}; },
    async resolveLocation() { throw new ServiceError('Current location lookup is not connected. Choose an area manually.','integration_unavailable'); }
  };
}

/** Integration boundary. Endpoint names are proposed, not a claim of an existing API.
 * Keep credentials outside source control. tokenProvider may return an in-memory token.
 * OTP responses: {id,phone,expiresAt,resendAt}; home: same shape as fixtures;
 * areas: {saved:[],recent:[]}; search: Area[]; confirm/resolve: Area.
 */
export function createBackendAdapter({baseUrl,tokenProvider=()=>null,fetchImpl=fetch}) {
  if(!baseUrl) throw new Error('A backend baseUrl is required.');
  async function request(route,body,{signal}={}) {
    const token=tokenProvider();
    const response=await fetchImpl(new URL(route,baseUrl.endsWith('/')?baseUrl:baseUrl+'/'),{
      method:body===undefined?'GET':'POST',signal,
      headers:{Accept:'application/json',...(body!==undefined?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`}:{})},
      ...(body!==undefined?{body:JSON.stringify(body)}:{})
    });
    const data=await response.json().catch(()=>null);
    if(!response.ok) throw new ServiceError(data?.message||'Could not complete the request. Please retry.',data?.code||String(response.status));
    if(data===null)throw new ServiceError('The service returned an invalid response.','invalid_response');
    return data;
  }
  return {mode:'backend',startOtp:phone=>request('auth/otp/start',{phone:normalizedPhone(phone)}),verifyOtp:(id,code)=>request('auth/otp/verify',{challengeId:id,code}),getHome:options=>request('frontend/home',undefined,options),getAreas:options=>request('frontend/areas',undefined,options),searchAreas:(query,options)=>request('frontend/areas/search',{query},options),confirmArea:area=>request('frontend/areas/confirm',{area}),resolveLocation:coordinates=>request('frontend/areas/resolve',{coordinates})};
}

export const services=window.PARCHI_CONFIG?.mode==='backend'
  ?createBackendAdapter(window.PARCHI_CONFIG):createDemoAdapter();
