// Widely stocked supplies do not have a useful quest destination. Keep scarce
// and limited-stock vendors mapped; this is display policy, not a data override.
function mappedVendors(item) {
  const vendors=Object.entries(item.vendors||{});
  const unlimited=vendors.filter(([,stock])=>Number(stock)===0);
  return unlimited.length>=10 ? [] : vendors.map(([id])=>id);
}
module.exports={mappedVendors};
