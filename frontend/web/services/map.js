/** Default map is deliberately unavailable. No tiles, SDK, location or keys load.
 * A future provider implements mount(element,{area,onSelect,onStatus}) => cleanup().
 * Area: {id,label,detail?,city?,coordinate?:{latitude,longitude}}.
 * Return selected Area through onSelect; status is ready/loading/unavailable/error.
 */
export function createUnavailableMapAdapter() {
  return {mount(element,{onStatus=()=>{}}={}) {
    element.dataset.mapStatus='unavailable';onStatus({state:'unavailable',message:'Map unavailable'});
    return ()=>{};
  }};
}
export const mapProvider=window.PARCHI_MAP_PROVIDER||createUnavailableMapAdapter();
