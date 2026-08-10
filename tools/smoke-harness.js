// 冒烟：用种子数据跑全部渲染/记录/建议路径，抓运行时空引用
var __fails = 0;
try {
  WScript.Echo('HARNESS_START');
  localStorage.setItem('wake-clock-records', JSON.stringify([
    { id: 'r1', sleepStart: '2026-08-05T02:30', wakeEnd: '2026-08-05T10:30' },
    { id: 'r2', sleepStart: '2026-08-06T04:30', wakeEnd: '2026-08-06T08:30' },
    { id: 'r3', sleepStart: '2026-08-06T18:00', wakeEnd: '2026-08-06T20:00' }
  ]));
  WScript.Echo('HARNESS_SEED_OK');
  localStorage.setItem('wake-clock-settings', JSON.stringify({ targetBed: '01:00', targetWake: '08:00', idealSleepH: 7, handColor: '紫', levels: { y: 16, o: 20, r: 24 } }));

  init(); WScript.Echo('HARNESS_INIT_OK');
  renderMain(); WScript.Echo('HARNESS_MAIN_OK');
  renderRecords(); WScript.Echo('HARNESS_RECORDS_OK');
  renderTrends(); WScript.Echo('HARNESS_TRENDS_OK');
  fillSettings(); WScript.Echo('HARNESS_SETTINGS_OK');
  askSleepy(); askReset(); WScript.Echo('HARNESS_ADVICE_OK');

  // 记录表单链路：打开/弹层选时间/醒晚于睡自动顺延/清空（回归：$('#x') 带井号空引用、不依赖原生选择器）
  openForm(null, '2026-08-06T22:00', '2026-08-07T06:00');
  if ($('rfId').value !== '') { __fails++; WScript.Echo('FAIL openForm id reset'); }
  if ($('rfSleep').value !== '2026-08-06T22:00') { __fails++; WScript.Echo('FAIL openForm sleep fill got=' + $('rfSleep').value); }
  if ($('rfWake').value !== '2026-08-07T06:00') { __fails++; WScript.Echo('FAIL openForm wake fill got=' + $('rfWake').value); }
  if ($('dtSleepVal').textContent !== '8月6日 22:00') { __fails++; WScript.Echo('FAIL sleep label got=' + $('dtSleepVal').textContent); }
  if ($('dtWakeVal').textContent !== '8月7日 06:00') { __fails++; WScript.Echo('FAIL wake label got=' + $('dtWakeVal').textContent); }
  // 弹层：打开入睡 → +1h → 确定（时间显示现在是打字框 dtTimeInput）
  pickField('sleep');
  if ($('dtSheet').classList.contains('hidden')) { __fails++; WScript.Echo('FAIL sheet not open'); }
  if ($('dtTimeInput').value !== '22:00') { __fails++; WScript.Echo('FAIL sheet initial time got=' + $('dtTimeInput').value); }
  dtShift(3600000);
  if ($('dtTimeInput').value !== '23:00') { __fails++; WScript.Echo('FAIL dtShift +1h got=' + $('dtTimeInput').value); }
  dtDone();
  if ($('rfSleep').value !== '2026-08-06T23:00') { __fails++; WScript.Echo('FAIL dtDone commit sleep got=' + $('rfSleep').value); }
  if ($('rfWake').value !== '2026-08-07T06:00') { __fails++; WScript.Echo('FAIL dtDone kept wake got=' + $('rfWake').value); }
  if (!$('dtSheet').classList.contains('hidden')) { __fails++; WScript.Echo('FAIL sheet not closed'); }
  // 打字框解析：HH:MM / 省冒号 / 非法
  var p1 = dtParseText('23:45');
  if (!p1 || p1.h !== 23 || p1.m !== 45) { __fails++; WScript.Echo('FAIL dtParseText HH:MM'); }
  var p2 = dtParseText('235');
  if (!p2 || p2.h !== 23 || p2.m !== 5) { __fails++; WScript.Echo('FAIL dtParseText short got=' + (p2 ? p2.h + ':' + p2.m : 'null')); }
  if (dtParseText('abc') !== null || dtParseText('99:99') !== null) { __fails++; WScript.Echo('FAIL dtParseText invalid'); }
  // 日期输入：M/D 与 YYYY/M/D 可解析，非法为 NaN
  if (isNaN(dtParseDate('8-7')) || isNaN(dtParseDate('2026/8/7'))) { __fails++; WScript.Echo('FAIL dtParseDate valid'); }
  if (!isNaN(dtParseDate('abc')) || !isNaN(dtParseDate('32-45'))) { __fails++; WScript.Echo('FAIL dtParseDate invalid'); }
  // 打字不再被自动回填打断：输 "1" 时输入框保持原文、时刻/滚轮跟随；失焦归一化；确定提交
  openForm(null, '2026-08-06T22:00', '2026-08-07T06:00');
  pickField('sleep');
  $('dtTimeInput').value = '1';
  dtOnInput();
  if ($('dtTimeInput').value !== '1') { __fails++; WScript.Echo('FAIL typing raw preserved got=' + $('dtTimeInput').value); }
  var dty = new Date(dtMs);
  if (dty.getHours() !== 1 || dty.getMinutes() !== 0) { __fails++; WScript.Echo('FAIL typing drives time h=' + dty.getHours()); }
  dtBlur();
  if ($('dtTimeInput').value !== '01:00') { __fails++; WScript.Echo('FAIL typing blur normalized got=' + $('dtTimeInput').value); }
  dtDone();
  if ($('rfSleep').value !== '2026-08-06T01:00') { __fails++; WScript.Echo('FAIL typing commit got=' + $('rfSleep').value); }
  // 滚轮循环：wrapIdx 边界环绕（分钟 59→0、时 23→0）
  if (wrapIdx(-1, 60) !== 59) { __fails++; WScript.Echo('FAIL wrapIdx -1'); }
  if (wrapIdx(60, 60) !== 0) { __fails++; WScript.Echo('FAIL wrapIdx 60'); }
  if (wrapIdx(-2, 24) !== 22) { __fails++; WScript.Echo('FAIL wrapIdx -2'); }
  if (wrapIdx(24, 24) !== 0) { __fails++; WScript.Echo('FAIL wrapIdx 24'); }
  if (wrapIdx(23, 24) !== 23) { __fails++; WScript.Echo('FAIL wrapIdx 23'); }
  // 备份/恢复：buildBackup 含 records/settings/pending，applyBackup 完整还原（旧文件无 pending 则清，不动 records）
  savePending({ sleepStart: Date.now() });
  var bk = buildBackup();
  if (!bk.pending) { __fails++; WScript.Echo('FAIL backup missing pending'); }
  if (!bk.settings || bk.settings.targetBed !== '01:00') { __fails++; WScript.Echo('FAIL backup missing settings'); }
  if (bk.records.length < 1) { __fails++; WScript.Echo('FAIL backup missing records'); }
  applyBackup(bk);
  if (!loadPending()) { __fails++; WScript.Echo('FAIL import restores pending'); }
  applyBackup({ settings: null });
  if (loadPending()) { __fails++; WScript.Echo('FAIL import clears pending when absent'); }
  // 配色：默认色号写进设置页输入框/色块，applyColors/applyOneColor 在 stub（无 documentElement）下不抛错
  applyColors();
  applyOneColor('bg', '#123456');
  fillSettings();
  if ($('setColBg').value !== '#d1e4ca' || $('swBg').style.background !== '#d1e4ca') { __fails++; WScript.Echo('FAIL colors fill got=' + $('setColBg').value + '/' + $('swBg').style.background); }
  // 单次睡眠时长图：跑一遍并确认有理想虚线 ref
  renderSleepDur(JSON.parse(localStorage.getItem('wake-clock-records')));
  if ($('sleepDurBars').innerHTML.indexOf('ref') < 0) { __fails++; WScript.Echo('FAIL sleepDur ref missing'); }
  // 设置页目标起床：纯时间弹层 +1h → 确定写回 HH:MM
  pickClockTime('setWake');
  if ($('dtDateRow').style.display !== 'none') { __fails++; WScript.Echo('FAIL time-only mode should hide date row'); }
  dtShift(3600000);
  dtDone();
  if ($('setWakeVal').textContent !== '09:00') { __fails++; WScript.Echo('FAIL clock-time setWake got=' + $('setWakeVal').textContent); }
  // 醒早于睡自动顺延：醒来 03:00 < 入睡 05:00 → 顺延为 05:00+7h
  openForm(null, '2026-08-07T05:00', '2026-08-07T03:00');
  pickField('wake'); dtDone();
  if ($('rfWake').value !== '2026-08-07T12:00') { __fails++; WScript.Echo('FAIL auto-follow wake got=' + $('rfWake').value); }
  openForm('r1', '2026-08-05T02:30', '2026-08-05T10:30');
  if ($('rfId').value !== 'r1') { __fails++; WScript.Echo('FAIL openForm edit id'); }
  clearForm();
  if ($('rfSleep').value !== '' || $('rfWake').value !== '') { __fails++; WScript.Echo('FAIL clearForm'); }
  // parseInput 单元断言：全 ISO / 月-日 / 纯 HH:MM
  if (parseInput('2026-08-06T22:00') !== new Date(2026, 7, 6, 22, 0).getTime()) { __fails++; WScript.Echo('FAIL parseInput ISO'); }
  var piShort = parseInput('08-06 22:00');
  if (piShort !== new Date((new Date()).getFullYear(), 7, 6, 22, 0).getTime()) { __fails++; WScript.Echo('FAIL parseInput MM-DD got=' + piShort); }
  var piH = parseInput('22:00'); var expH = new Date(); expH.setHours(22, 0, 0, 0);
  if (piH !== expH.getTime()) { __fails++; WScript.Echo('FAIL parseInput HH:MM'); }
  WScript.Echo('HARNESS_FORM_OK');

  sleepDown();
  if (!localStorage.getItem('wake-clock-pending')) { __fails++; WScript.Echo('FAIL pending not set'); }
  wakeNow();
  var after = JSON.parse(localStorage.getItem('wake-clock-records'));
  if (after.length !== 4) { __fails++; WScript.Echo('FAIL wakeNow count=' + after.length); }

  $('rfSleep').value = '2026-08-06T22:00';
  $('rfWake').value = '2026-08-07T06:00';
  onRecordSubmit({ preventDefault: function () { } });
  var after2 = JSON.parse(localStorage.getItem('wake-clock-records'));
  if (after2.length !== 5) { __fails++; WScript.Echo('FAIL submit count=' + after2.length); }

  var st = stateAt(Date.now());
  if (!(st.E >= 0)) { __fails++; WScript.Echo('FAIL stateAt E=' + st.E); }
  if (st.felt == null) { __fails++; WScript.Echo('FAIL felt null'); }
  // 主屏债务副读 + 刚醒不劝睡（合成 justWoke 状态直接测建议）
  if (typeof st.debt !== 'number' || st.debt < 0) { __fails++; WScript.Echo('FAIL stateAt.debt'); }
  renderMain();
  if ($('debtLine').textContent.indexOf('累计清醒负债') < 0) { __fails++; WScript.Echo('FAIL debtLine missing got=' + $('debtLine').textContent); }
  var stJ = { E: 30, dev: 14, felt: 23, actual: 23, awakeH: 0.5, sleeping: false, records: [], sleep24: 6, pending: null, anchor: null };
  var advJ = generateAdvice(stJ);
  if (advJ.body.indexOf('该睡了') >= 0 || advJ.body.indexOf('现在就去睡') >= 0) { __fails++; WScript.Echo('FAIL just-woke advice pushes sleep got=' + advJ.body); }
  var advN = generateAdvice({ E: 22, dev: 6, felt: 23, actual: 23, awakeH: 8, sleeping: false, records: [], sleep24: 6, pending: null, anchor: null });
  if (advN.body.indexOf('已到极限') < 0) { __fails++; WScript.Echo('FAIL awake-8h E=22 should say limit got=' + advN.body); }

  // file:// 打开场景：init 不得抛错（原生时间选择器失效另由引导横幅提示）
  location.protocol = 'file:';
  init();
  location.protocol = 'http:';
  WScript.Echo('HARNESS_FILEOK');

  if (__fails > 0) { WScript.Echo('== DOM SMOKE ' + __fails + ' FAILED =='); WScript.Quit(1); }
  WScript.Echo('== DOM SMOKE OK ==');
} catch (e) { WScript.Echo('SMOKE THREW: ' + (e.message || e)); WScript.Quit(1); }
