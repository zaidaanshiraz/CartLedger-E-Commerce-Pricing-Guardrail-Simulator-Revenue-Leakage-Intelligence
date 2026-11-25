// ============================================================================
// CARTLEDGER — ENTERPRISE SQL, PRICING SIMULATOR & BASKET CONTROLLER
// Author: Mohammed Zaidaan Shiraz
// ============================================================================

let caseFiles = [];
let overviewData = null;
let lastQueryResult = null;
let activeView = 'executive';

const PLOTLY_CONFIG = { responsive: true, displayModeBar: false };

function fmtINRCompact(num) {
  if (num === null || num === undefined) return '—';
  const n = Number(num);
  if (Math.abs(n) >= 10000000) return '₹' + (n / 10000000).toFixed(2) + 'Cr';
  if (Math.abs(n) >= 1000000) return '₹' + (n / 1000000).toFixed(2) + 'M';
  if (Math.abs(n) >= 1000) return '₹' + (n / 1000).toFixed(1) + 'K';
  return '₹' + n.toLocaleString('en-IN');
}

function fmtINR(v) {
  if (v === null || v === undefined) return '—';
  return '₹' + Number(v).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function renderMiniSparkline(divId, values) {
  if (!values || !values.length || !window.Plotly) return;
  const el = document.getElementById(divId);
  if (!el) return;
  const x = values.map((_, i) => i);
  const maxIdx = values.indexOf(Math.max(...values));
  const minIdx = values.indexOf(Math.min(...values));

  Plotly.newPlot(divId, [
    {
      x,
      y: values,
      type: 'scatter',
      mode: 'lines',
      fill: 'tozeroy',
      line: { color: '#5A636C', width: 1.5 },
      fillcolor: 'rgba(157, 147, 134, 0.38)',
      hoverinfo: 'skip'
    },
    {
      x: [minIdx, maxIdx],
      y: [values[minIdx], values[maxIdx]],
      type: 'scatter',
      mode: 'markers',
      marker: { color: '#1F2428', size: 4.5 },
      hoverinfo: 'skip'
    }
  ], {
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    margin: { t: 4, r: 4, b: 4, l: 4 },
    xaxis: { visible: false },
    yaxis: { visible: false },
    showlegend: false
  }, PLOTLY_CONFIG);
}

const VIEW_TITLES = {
  executive: 'Revenue & Profitability Overview',
  simulator: 'Prescriptive Pricing Guardrail & Dunning Simulator',
  basket: 'Market Basket, Cohort LTV, CFO PVM Bridge & Data Contracts',
  studio: '16 Interactive SQL Case Files & EXPLAIN Plan Studio'
};

function switchTab(tab) {
  activeView = tab;
  const views = ['executive', 'simulator', 'basket', 'studio'];
  views.forEach(v => {
    const vEl = document.getElementById(`view-${v}`);
    const bEl = document.getElementById(`btn-${v}`);
    if (vEl && bEl) {
      if (v === tab) {
        vEl.classList.remove('hidden');
        bEl.classList.add('active');
      } else {
        vEl.classList.add('hidden');
        bEl.classList.remove('active');
      }
    }
  });

  const titleEl = document.getElementById('header-title');
  if (titleEl && VIEW_TITLES[tab]) {
    titleEl.textContent = VIEW_TITLES[tab];
  }

  if (tab === 'executive' && overviewData) {
    renderExecutiveCharts(overviewData);
  } else if (tab === 'simulator') {
    updatePricingSimulation();
  }
  window.dispatchEvent(new Event('resize'));
}

function setTierSlicer(val, btnEl) {
  const tierInput = document.getElementById('filter-tier');
  if (tierInput) tierInput.value = val;

  document.querySelectorAll('.tier-pill').forEach(b => {
    b.classList.toggle('active', b === btnEl || b.getAttribute('data-tier') === val);
  });

  refreshOverview();
}

function resetCartLedgerFilters() {
  const reg = document.getElementById('filter-region');
  if (reg) reg.value = 'All';
  const tier = document.getElementById('filter-tier');
  if (tier) tier.value = 'All';
  document.querySelectorAll('.tier-pill').forEach((b, i) => b.classList.toggle('active', i === 0));
  refreshOverview();
}

async function initCartLedger() {
  try {
    if (window.lucide) lucide.createIcons();
  } catch (e) {
    console.warn('Lucide init skipped:', e);
  }

  await Promise.all([
    refreshOverview(),
    loadCaseFilesCatalog(),
    updatePricingSimulation()
  ]);
}

async function refreshOverview() {
  const region = (document.getElementById('filter-region') || {}).value || 'All';
  const tier = (document.getElementById('filter-tier') || {}).value || 'All';
  const params = new URLSearchParams({ region, tier });

  const ovRes = await fetch(`/api/overview?${params.toString()}`);
  overviewData = await ovRes.json();

  const b = overviewData.bridge;

  // Update Header Scope Badge
  const scopeBadge = document.getElementById('cl-scope-badge');
  if (scopeBadge) {
    const rTag = region === 'All' ? 'All Regions' : `Region: ${region}`;
    const tTag = tier === 'All' ? 'All Tiers' : `Tier: ${tier}`;
    scopeBadge.textContent = `Scope: ${rTag} · ${tTag} · ${b.completed_paid_orders.toLocaleString()} Paid Orders`;
  }

  document.getElementById('kpi-gross').textContent = fmtINRCompact(b.gross_sales_inr);
  document.getElementById('kpi-orders').textContent = b.completed_paid_orders.toLocaleString();
  document.getElementById('kpi-units').textContent = `▲ ${b.gross_units_sold.toLocaleString()}`;
  document.getElementById('kpi-netsales').textContent = fmtINRCompact(b.net_sales_ex_tax_inr);
  document.getElementById('kpi-discounts').textContent = fmtINRCompact(b.total_discounts_inr);
  const mdPct = b.gross_sales_inr > 0 ? ((b.total_discounts_inr / b.gross_sales_inr) * 100).toFixed(2) : '0.00';
  document.getElementById('kpi-markdown-pct').textContent = `-${mdPct}%`;
  document.getElementById('kpi-tax').textContent = fmtINRCompact(b.tax_collected_inr);
  document.getElementById('kpi-refunds').textContent = fmtINRCompact(b.approved_refunds_inr);
  document.getElementById('kpi-returns-units').textContent = `${b.returned_units} Units`;
  document.getElementById('kpi-realized').textContent = fmtINRCompact(b.net_realized_revenue_inr);
  document.getElementById('kpi-leakage').textContent = fmtINRCompact(overviewData.pending_leakage_inr);

  // Render Top 5 Sparklines
  const m = overviewData.monthly_trend || [];
  if (m.length > 0) {
    renderMiniSparkline('spark-cl-1', m.map(r => r.net_sales_inr * 1.09));
    renderMiniSparkline('spark-cl-2', m.map(r => r.net_sales_inr));
    renderMiniSparkline('spark-cl-3', m.map(r => r.gross_profit_inr));
    renderMiniSparkline('spark-cl-4', m.map(r => r.paid_orders));
    renderMiniSparkline('spark-cl-5', m.map((r, i) => r.net_sales_inr * (0.06 + (i % 3) * 0.01)));
  }

  // Row 2 Right: Top Categories Horizontal Bars
  const cats = (overviewData.categories || []).slice(0, 4);
  const maxProfit = cats.length ? Math.max(...cats.map(c => c.gross_profit_inr)) : 1;
  const barColors = ['#2C343D', '#6E685F', '#9D9386', '#B8B0A4'];
  document.getElementById('top-cat-bars').innerHTML = cats.map((c, i) => {
    const pct = Math.max(25, Math.round((c.gross_profit_inr / maxProfit) * 100));
    const shortCat = c.category_name.split('&')[0].trim();
    return `
      <div class="grid grid-cols-12 items-center gap-2 text-[11px]">
        <div class="col-span-4 font-medium text-[#1F2428] truncate" title="${c.category_name}">${shortCat}</div>
        <div class="col-span-8 bg-[#E2DDD5] rounded-md h-6 overflow-hidden flex items-center">
          <div style="width:${pct}%; background-color:${barColors[i % barColors.length]};" class="h-full rounded-md flex items-center justify-end px-2 text-[10px] font-mono font-semibold text-white">
            ${fmtINRCompact(c.gross_profit_inr)}
          </div>
        </div>
      </div>
    `;
  }).join('');

  // Row 3 Left: Loss-Making / Lowest-Margin SKUs Table
  const lossSkus = overviewData.loss_making_skus || [];
  document.getElementById('loss-sku-tbody').innerHTML = lossSkus.map((s, idx) => {
    const val = Number(s.net_loss_inr || 0);
    const isNeg = val < 0;
    const fmtVal = isNeg ? `-${fmtINR(Math.abs(val))}` : `+${fmtINR(val)}`;
    const colorCls = isNeg ? 'text-[#A63A3A]' : 'text-[#323A45]';
    return `
      <tr class="hover:bg-[#EAE5DE]">
        <td class="py-1.5 px-2 font-mono font-semibold text-[#1F2428] flex items-center gap-1.5">
          <span class="w-4 h-4 rounded-full bg-[#2C343D] text-white text-[9px] flex items-center justify-center font-bold">${idx + 1}</span>
          ${s.product_id}
        </td>
        <td class="py-1.5 px-2 text-[#323A45] truncate max-w-[150px]">${s.category_name}</td>
        <td class="py-1.5 px-2 text-right font-mono">${s.units_sold}</td>
        <td class="py-1.5 px-2 text-right font-mono font-bold ${colorCls}">${fmtVal}</td>
      </tr>
    `;
  }).join('');

  // Row 3 Center: Category Margin Pill Bars
  const allCats = (overviewData.categories || []).slice(0, 6);
  const maxMargin = allCats.length ? Math.max(...allCats.map(c => c.weighted_margin_pct)) : 1;
  const pillShades = ['#2C343D', '#4A525A', '#686E73', '#7E7870', '#968E83', '#ACA499'];
  document.getElementById('cat-pill-bars').innerHTML = allCats.map((c, i) => {
    const wPct = Math.max(30, Math.round((c.weighted_margin_pct / maxMargin) * 100));
    const shortCat = c.category_name.split('&')[0].trim();
    return `
      <div class="grid grid-cols-12 items-center gap-2 text-[11px]">
        <div class="col-span-4 font-semibold text-[#1F2428] truncate">${shortCat}</div>
        <div class="col-span-8 flex items-center">
          <div style="width:${wPct}%; background-color:${pillShades[i % pillShades.length]};" class="h-5 rounded-full flex items-center justify-end px-2.5 text-[10px] font-mono font-semibold text-white">
            ${c.weighted_margin_pct.toFixed(1)}%
          </div>
        </div>
      </div>
    `;
  }).join('');

  // Populate View 3: Market Basket Affinity Table (CF-13)
  const pairs = overviewData.basket_pairs || [];
  document.getElementById('basket-tbody').innerHTML = pairs.map(p => `
    <tr class="hover:bg-[#EAE5DE]">
      <td class="py-1.5 px-2.5 font-sans font-medium text-[#1F2428]">${p.category_a.split('&')[0].trim()} + <strong>${p.category_b.split('&')[0].trim()}</strong></td>
      <td class="py-1.5 px-2.5 text-right font-bold">${p.co_purchased_orders}</td>
      <td class="py-1.5 px-2.5 text-right">${p.support_pct}%</td>
      <td class="py-1.5 px-2.5 text-right">${p.confidence_a_to_b_pct}%</td>
      <td class="py-1.5 px-2.5 text-right font-bold text-[#2B6E46]">${p.lift_ratio}x</td>
    </tr>
  `).join('');

  // Populate View 3: Cohort Retention & Repeat LTV Table (CF-14)
  const cohorts = overviewData.cohorts || [];
  document.getElementById('cohort-tbody').innerHTML = cohorts.map(c => `
    <tr class="hover:bg-[#EAE5DE]">
      <td class="py-1.5 px-2.5 font-bold text-[#1F2428]">${c.cohort_month}</td>
      <td class="py-1.5 px-2.5 text-right">${c.cohort_customers}</td>
      <td class="py-1.5 px-2.5 text-right font-bold text-[#2B6E46]">${c.repeat_retention_pct}%</td>
      <td class="py-1.5 px-2.5 text-right">${c.avg_orders_per_buyer}</td>
      <td class="py-1.5 px-2.5 text-right font-bold text-[#1F2428]">${fmtINR(c.avg_customer_ltv_inr)}</td>
    </tr>
  `).join('');

  // Populate View 3: SQL Anti-Pattern vs Production Fix Table (CF-15)
  const traps = overviewData.sql_traps || [];
  document.getElementById('sql-traps-tbody').innerHTML = traps.map(t => `
    <tr class="hover:bg-[#EAE5DE]">
      <td class="py-2 px-3 font-sans font-semibold text-[#1F2428]">${t.audit_check}</td>
      <td class="py-2 px-3 text-right font-bold text-[#A63A3A]">${Number(t.naive_buggy_metric).toLocaleString()}</td>
      <td class="py-2 px-3 text-right font-bold text-[#2B6E46]">${Number(t.production_fixed_metric).toLocaleString()}</td>
      <td class="py-2 px-3 text-right font-bold text-[#1F2428]">+${t.distortion_error_pct}% Variance Fixed</td>
    </tr>
  `).join('');

  // Populate View 3: CFO Price-Volume-Mix (PVM) Decomposition Bridge (CF-16)
  const pvm = overviewData.pvm_bridge || [];
  const pvmBody = document.getElementById('pvm-tbody');
  if (pvmBody) {
    pvmBody.innerHTML = pvm.map(r => {
      const volCls = r.volume_effect_inr >= 0 ? 'text-[#2B6E46]' : 'text-[#A63A3A]';
      const prcCls = r.price_promo_effect_inr >= 0 ? 'text-[#2B6E46]' : 'text-[#A63A3A]';
      const netCls = r.total_profit_variance_inr >= 0 ? 'text-[#2B6E46]' : 'text-[#A63A3A]';
      return `
        <tr class="hover:bg-[#EAE5DE]">
          <td class="py-1.5 px-2.5 font-sans font-semibold text-[#1F2428]">${r.category_name.split('&')[0].trim()}</td>
          <td class="py-1.5 px-2.5 text-right">${fmtINR(r.h1_profit_inr)}</td>
          <td class="py-1.5 px-2.5 text-right font-semibold ${volCls}">${r.volume_effect_inr >= 0 ? '+' : ''}${fmtINR(r.volume_effect_inr)}</td>
          <td class="py-1.5 px-2.5 text-right font-semibold ${prcCls}">${r.price_promo_effect_inr >= 0 ? '+' : ''}${fmtINR(r.price_promo_effect_inr)}</td>
          <td class="py-1.5 px-2.5 text-right">${fmtINR(r.h2_profit_inr)}</td>
          <td class="py-1.5 px-2.5 text-right font-bold ${netCls}">${r.total_profit_variance_inr >= 0 ? '+' : ''}${fmtINR(r.total_profit_variance_inr)}</td>
        </tr>
      `;
    }).join('');
  }

  // Populate View 3: Automated General Ledger & Schema Data Contracts
  const dc = overviewData.data_contracts || [];
  const dcBody = document.getElementById('contracts-tbody');
  if (dcBody) {
    dcBody.innerHTML = dc.map(c => `
      <tr class="hover:bg-[#EAE5DE]">
        <td class="py-1.5 px-2 font-bold text-[#1F2428]">${c.contract_id}</td>
        <td class="py-1.5 px-2 font-sans text-[#323A45]">${c.assertion}</td>
        <td class="py-1.5 px-2 text-right">${c.expected} == <strong>${c.actual}</strong></td>
        <td class="py-1.5 px-2 text-right"><span class="px-1.5 py-0.5 rounded bg-[#DCE8DF] text-[#1E4D30] font-bold">${c.status}</span></td>
      </tr>
    `).join('');
  }

  renderExecutiveCharts(overviewData);
}

// ----------------------------------------------------------------------------
// PRESCRIPTIVE PRICING GUARDRAIL & DUNNING SIMULATOR
// ----------------------------------------------------------------------------
async function updatePricingSimulation() {
  const capEl = document.getElementById('sim-cap-slider');
  const dunEl = document.getElementById('sim-dunning-slider');
  const capVal = capEl ? Number(capEl.value) : 8;
  const dunVal = dunEl ? Number(dunEl.value) : 65;

  const capLabel = document.getElementById('sim-cap-val');
  if (capLabel) capLabel.textContent = `${capVal}%`;
  const dunLabel = document.getElementById('sim-dunning-val');
  if (dunLabel) dunLabel.textContent = `${dunVal}%`;

  const res = await fetch(`/api/simulate-recovery?discount_cap=${capVal}&dunning_recovery_pct=${dunVal}`);
  const sim = await res.json();

  document.getElementById('sim-base-profit').textContent = fmtINR(sim.baseline_gross_profit_inr);
  document.getElementById('sim-margin-gain').textContent = `+${fmtINR(sim.margin_recovery_gain_inr)}`;
  document.getElementById('sim-new-margin').textContent = `${sim.simulated_margin_pct.toFixed(2)}% (+${sim.margin_lift_bps} bps)`;
  document.getElementById('sim-dunning-cash').textContent = `+${fmtINR(sim.recovered_leakage_cash_inr)} (${sim.pending_orders_count} orders)`;
  document.getElementById('sim-skus-flipped').textContent = `${sim.loss_skus_flipped_profitable} / ${sim.loss_skus_total} SKUs Profitable`;
  document.getElementById('sim-total-uplift').textContent = `+${fmtINR(sim.total_bottom_line_profit_uplift_inr)}`;

  const skuRows = sim.sku_remediation_table || [];
  document.getElementById('sim-sku-tbody').innerHTML = skuRows.map(r => {
    const isNowPos = r.simulated_profit_inr >= 0;
    return `
      <tr class="hover:bg-[#EAE5DE]">
        <td class="py-2 px-3 font-bold text-[#1F2428]">${r.product_id}</td>
        <td class="py-2 px-3 font-sans">${r.product_name} · <span class="text-[#686E73]">${r.category_name}</span></td>
        <td class="py-2 px-3 text-right">${r.units_sold}</td>
        <td class="py-2 px-3 text-right">${r.current_avg_discount_pct}% → <strong>${r.capped_avg_discount_pct}%</strong></td>
        <td class="py-2 px-3 text-right text-[#A63A3A] font-bold">${fmtINR(r.current_profit_inr)}</td>
        <td class="py-2 px-3 text-right ${isNowPos ? 'text-[#2B6E46]' : 'text-[#A63A3A]'} font-bold">${fmtINR(r.simulated_profit_inr)}</td>
        <td class="py-2 px-3 text-right text-[#2B6E46] font-bold">+${fmtINR(r.profit_recovered_inr)}</td>
      </tr>
    `;
  }).join('');

  if (window.Plotly && skuRows.length > 0 && activeView === 'simulator') {
    Plotly.newPlot('chart-sim-skus', [
      {
        x: skuRows.map(r => `${r.product_id} (${r.product_name.split(' ')[0]})`),
        y: skuRows.map(r => r.current_profit_inr),
        name: 'Current Net Loss (Uncapped Promo)',
        type: 'bar',
        marker: { color: '#C8C0B5' }
      },
      {
        x: skuRows.map(r => `${r.product_id} (${r.product_name.split(' ')[0]})`),
        y: skuRows.map(r => r.simulated_profit_inr),
        name: `Simulated Profit (${capVal}% Promo Cap)`,
        type: 'bar',
        marker: { color: '#2C343D' }
      }
    ], {
      barmode: 'group',
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: 'rgba(0,0,0,0)',
      font: { family: 'Inter, sans-serif', color: '#1F2428', size: 11 },
      margin: { t: 16, r: 16, b: 32, l: 48 },
      legend: { orientation: 'h', y: 1.14, x: 0 }
    }, PLOTLY_CONFIG);
  }
}

function renderExecutiveCharts(ov) {
  if (!window.Plotly) return;
  // 1. Row 2 Left: Discount Band Column Chart (Center Dark Slate Bar)
  const d = (ov.discount_bands || []).slice(0, 3);
  const xLabels = d.map(r => r.discount_band.replace(/^\d+\.\s*/, ''));
  const yVals = d.map(r => r.net_sales_inr);
  const barColors = ['#DFD8CE', '#2C343D', '#C8C0B5'];
  const textColors = ['#1F2428', '#FFFFFF', '#1F2428'];

  Plotly.newPlot('chart-discount-columns', [
    {
      x: xLabels,
      y: yVals,
      type: 'bar',
      text: yVals.map(v => fmtINRCompact(v)),
      textposition: 'inside',
      insidetextanchor: 'start',
      textfont: { family: 'Inter, sans-serif', size: 11, color: textColors, weight: 'bold' },
      marker: { color: barColors, line: { color: '#B8B0A4', width: 1 } },
      width: [0.52, 0.52, 0.52]
    }
  ], {
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    font: { family: 'Inter, sans-serif', color: '#1F2428', size: 11 },
    margin: { t: 12, r: 12, b: 28, l: 12 },
    xaxis: { showgrid: false, zeroline: false },
    yaxis: { visible: false }
  }, PLOTLY_CONFIG);

  // 2. Row 2 Center: RFM Donut
  const rfm = ov.rfm_segments || [];
  Plotly.newPlot('chart-rfm-donut', [
    {
      labels: rfm.map(r => r.rfm_segment.replace(/^\d+\.\s*/, '')),
      values: rfm.map(r => r.segment_total_revenue_inr),
      type: 'pie',
      hole: 0.48,
      marker: {
        colors: ['#2C343D', '#5A636C', '#8C8275', '#B8B0A4', '#D5CFC7'],
        line: { color: '#F3EFEA', width: 2 }
      },
      textinfo: 'label+percent',
      textposition: 'outside',
      automargin: true,
      textfont: { size: 10, color: '#1F2428' }
    }
  ], {
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    margin: { t: 10, r: 20, b: 10, l: 20 },
    showlegend: false
  }, PLOTLY_CONFIG);

  // 3. Row 3 Right: Order Settlement Leakage Donut
  const lk = ov.leakage_matrix || [];
  Plotly.newPlot('chart-leakage-donut', [
    {
      labels: lk.map(r => `${r.order_status} (${r.payment_status})`),
      values: lk.map(r => r.distinct_orders),
      type: 'pie',
      hole: 0.52,
      marker: {
        colors: ['#2C343D', '#8C8275', '#B8B0A4', '#D5CFC7'],
        line: { color: '#F3EFEA', width: 2 }
      },
      textinfo: 'percent',
      textposition: 'outside',
      automargin: true,
      textfont: { size: 10.5, color: '#1F2428' }
    }
  ], {
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    margin: { t: 8, r: 16, b: 36, l: 16 },
    showlegend: true,
    legend: { orientation: 'h', y: -0.18, x: 0.5, xanchor: 'center', font: { size: 9.5, color: '#1F2428' } }
  }, PLOTLY_CONFIG);
}

async function loadCaseFilesCatalog() {
  const cfRes = await fetch('/api/case-files');
  const cfJson = await cfRes.json();
  caseFiles = cfJson.case_files || [];
  renderCaseFilesList();
  if (caseFiles.length > 0) await selectCaseFile(0);
}

function renderCaseFilesList() {
  const container = document.getElementById('case-files-list');
  if (!container) return;
  container.innerHTML = caseFiles.map((cf, i) => `
    <button type="button" onclick="selectCaseFile(${i})" id="cf-item-${i}" class="case-btn w-full text-left p-2.5 rounded-lg space-y-0.5">
      <div class="flex items-center justify-between">
        <span class="text-[10px] font-mono font-bold opacity-80">${cf.id}</span>
        <span class="text-[10px] font-mono opacity-70">${cf.level.split('·')[0]}</span>
      </div>
      <div class="text-xs font-bold">${cf.title}</div>
      <div class="text-[10px] opacity-75 truncate">${cf.sql_concepts}</div>
    </button>
  `).join('');
}

async function selectCaseFile(idx) {
  const cf = caseFiles[idx];
  if (!cf) return;

  caseFiles.forEach((_, i) => {
    const btn = document.getElementById(`cf-item-${i}`);
    if (btn) btn.classList.toggle('active', i === idx);
  });

  document.getElementById('cf-badge').textContent = `${cf.id} · ${cf.level}`;
  document.getElementById('cf-title').textContent = cf.title;
  document.getElementById('cf-problem').textContent = cf.business_problem;
  document.getElementById('cf-concepts').textContent = `SQL Techniques: ${cf.sql_concepts}`;
  document.getElementById('sql-editor').value = cf.sql;

  await runSelectedSQL();
}

async function runSelectedSQL() {
  const sql = document.getElementById('sql-editor').value;
  const res = await fetch('/api/query', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sql })
  });
  const data = await res.json();
  lastQueryResult = data;

  const status = document.getElementById('sql-status');
  const pillsEl = document.getElementById('dba-telemetry-pills');
  const planEl = document.getElementById('dba-plan-steps');

  if (data.valid) {
    status.className = 'rounded p-2.5 text-xs font-mono border bg-[#DCE8DF] border-[#B8D0BF] text-[#1E4D30]';
    status.textContent = `[READ-ONLY EXECUTION PASSED · ${data.execution_ms} ms] Returned ${data.row_count.toLocaleString()} row(s)`;

    const d = data.dba_diagnostics || {};
    if (pillsEl) {
      pillsEl.innerHTML = `
        <span class="px-2 py-0.5 rounded bg-[#2C343D] text-white font-semibold">Latency: ${data.execution_ms} ms</span>
        <span class="px-2 py-0.5 rounded bg-[#DCE8DF] text-[#1E4D30] font-semibold">Index Seeks: ${d.index_seeks_count ?? 0}</span>
        <span class="px-2 py-0.5 rounded bg-[#F3EFEA] border border-[#DCD6CD] text-[#1F2428]">CTEs: ${d.ctes_count ?? 0}</span>
        <span class="px-2 py-0.5 rounded bg-[#F3EFEA] border border-[#DCD6CD] text-[#1F2428]">Window: ${(d.window_functions || []).join(', ')}</span>
        <span class="px-2 py-0.5 rounded bg-[#DCE8DF] text-[#1E4D30] font-semibold">${d.fanout_safety || 'SAFE'}</span>
      `;
    }
    if (planEl) {
      const steps = data.query_plan || [];
      planEl.innerHTML = steps.length
        ? steps.map((s, idx) => `<div><span class="text-[#686E73]">Plan[${idx}]:</span> <strong>${s}</strong></div>`).join('')
        : '<div>Physical plan executed via SQLite B-Tree engine.</div>';
    }
  } else {
    status.className = 'rounded p-2.5 text-xs font-mono border bg-[#EAD8D8] border-[#D6B8B8] text-[#8B2626]';
    status.textContent = `[GUARDRAIL BLOCKED] ${data.message}`;
    if (pillsEl) pillsEl.innerHTML = `<span class="px-2 py-0.5 rounded bg-[#EAD8D8] text-[#8B2626] font-bold">BLOCKED BY AST GUARDRAIL</span>`;
    if (planEl) planEl.innerHTML = `<div>Query blocked prior to SQLite planner compilation.</div>`;
  }

  const thead = document.getElementById('sql-thead');
  const tbody = document.getElementById('sql-tbody');
  if (!data.valid || !data.columns || !data.columns.length) {
    thead.innerHTML = '';
    tbody.innerHTML = '';
    return;
  }

  thead.innerHTML = `<tr>${data.columns.map(c => `<th class="py-2 px-3">${c}</th>`).join('')}</tr>`;
  tbody.innerHTML = data.rows.map(r => `
    <tr class="hover:bg-[#EAE5DE]">
      ${data.columns.map(c => `<td class="py-2 px-3 text-[#1F2428]">${r[c] !== null && r[c] !== undefined ? r[c] : 'NULL'}</td>`).join('')}
    </tr>
  `).join('');
}

async function testCartLedgerGuardrail() {
  document.getElementById('sql-editor').value = 'DROP TABLE orders;';
  await runSelectedSQL();
}

function exportResultCSV() {
  if (!lastQueryResult || !lastQueryResult.valid || !lastQueryResult.rows || !lastQueryResult.rows.length) return;
  const cols = lastQueryResult.columns;
  const lines = [
    cols.join(','),
    ...lastQueryResult.rows.map(r => cols.map(c => `"${String(r[c] ?? '').replace(/"/g, '""')}"`).join(','))
  ];
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'cartledger_sql_case_export.csv';
  a.click();
}

window.addEventListener('DOMContentLoaded', initCartLedger);
