$ErrorActionPreference = 'Stop'
$root = 'D:\wake-clock'
$html = Get-Content -Raw -Encoding UTF8 "$root\index.html"

# 写临时 js：用系统 ANSI 编码（本机 GBK），cscript 原生可读、中文不乱
function Write-TestFile($path, $content){
  [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::Default)
}
# 跑 cscript，返回输出（cscript 出错时退出码可能是 0，所以用输出标记判定）
# 注意：EAP=Stop 时 cscript 的 stderr 会变成终止错误吞掉输出，这里临时降为 Continue
function Run-Cscript($file){
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $out = (& cscript //nologo $file 2>&1 | Out-String)
  $ErrorActionPreference = $prev
  return $out
}
$allOk = $true

# ============ 1) 核心算法功能测试 ============
$m = [regex]::Match($html, '(?s)// ===CORE-START===\r?\n(.*?)\r?\n// ===CORE-END===')
if(-not $m.Success){ Write-Error 'CORE markers not found'; exit 1 }
$core = $m.Groups[1].Value

$test = @'
var __fails = 0;
function D(y,m,d,h,min){ return new Date(y,m-1,d,h,min).getTime(); }
function T(label,got,exp){ if(Math.abs(got-exp)<=0.01){ WScript.Echo('PASS  '+label); } else { __fails++; WScript.Echo('FAIL  '+label+'  got='+got+'  exp='+exp); } }
function TS(label,got,exp){ if(got===exp){ WScript.Echo('PASS  '+label); } else { __fails++; WScript.Echo('FAIL  '+label+'  got='+got+'  exp='+exp); } }
var L={y:16,o:20,r:24};

var b=[
  {s:D(2026,8,5,2,30), e:D(2026,8,5,10,30)},
  {s:D(2026,8,6,4,30), e:D(2026,8,6,8,30)},
  {s:D(2026,8,6,18,0), e:D(2026,8,6,20,0)}
];
var r=computeEAt(b, D(2026,8,6,22,0));
var felt1=(((timeOfDay(r.anchor)+r.E)%24)+24)%24;
T('1.E(22:00)=17.5', r.E, 17.5);
T('1.anchor=昨天10:30', timeOfDay(r.anchor), 10.5);
T('1.felt=04:00', felt1, 4);
T('1.清醒超=1.5', r.E-16, 1.5);
TS('1.等级=疲劳', levelOf(r.E,L).name, '疲劳');
T('1.最近24h睡眠=6h', rollingSleep24(b, D(2026,8,6,22,0)), 6);

var r2=computeEAt(b, D(2026,8,6,8,30));
T('2.E(8:30)=10', r2.E, 10);
T('2.felt(8:30)=20:30', (((timeOfDay(r2.anchor)+r2.E)%24)+24)%24, 20.5);

var r3=computeEAt(b, D(2026,8,6,4,30));
T('3.E(4:30)=18', r3.E, 18);
T('3.felt(4:30)=04:30', (((timeOfDay(r3.anchor)+r3.E)%24)+24)%24, 4.5);

var c=[
  {s:D(2026,8,4,8,0), e:D(2026,8,4,16,0)},
  {s:D(2026,8,5,8,0), e:D(2026,8,5,12,0)},
  {s:D(2026,8,5,16,0),e:D(2026,8,5,19,0)},
  {s:D(2026,8,5,21,0),e:D(2026,8,6,1,0)}
];
var rc=computeEAt(c, D(2026,8,6,1,0));
T('4.累计恢复 E=0', rc.E, 0);
T('4.anchor=8/6 01:00', timeOfDay(rc.anchor), 1);
T('4.felt=01:00', (((timeOfDay(rc.anchor)+rc.E)%24)+24)%24, 1);

var d5=[{s:D(2026,8,5,2,0),e:D(2026,8,5,8,0)}];
var rd=computeEAt(d5, D(2026,8,6,14,0));
T('5.E不封顶=30(醒30h)', rd.E, 30);
T('5.felt=14:00', (((timeOfDay(rd.anchor)+rd.E)%24)+24)%24, 14);
T('5.清醒超=14(醒30h)', rd.E-16, 14);
TS('5.等级=极限', levelOf(rd.E,L).name, '极限');

// 6.「极限却绿」回归：校准点后睡5h+4h未归零，再醒23h → E=24 极限，清醒超=8h（红），不再是慢/绿
var d6=[
  {s:D(2026,8,6,2,30),e:D(2026,8,6,10,30)},
  {s:D(2026,8,7,2,30),e:D(2026,8,7,7,30)},
  {s:D(2026,8,7,10,30),e:D(2026,8,7,14,30)}
];
var r6=computeEAt(d6, D(2026,8,8,13,30));
T('6.E=24(极限)', r6.E, 24);
T('6.清醒超=8(红而非绿)', r6.E-16, 8);

// 7.活体等效清醒：睡够≥5h醒来重新锚定（E=还欠多少、校准点=这次醒来）；短nap仍累计递减
var d7=[
  {s:D(2026,8,9,22,45),e:D(2026,8,10,5,58)},   // 7.2h 睡够
  {s:D(2026,8,10,17,0),e:D(2026,8,10,18,20)}   // 1.3h 短nap
];
var l7=computeEAtLive(d7, D(2026,8,10,5,58), 7);
T('7.睡7.2h活体E=0', l7.E, 0);
T('7.锚定=8/10 5:58', timeOfDay(l7.anchor), 5.9667);
var l8=computeEAtLive(d7, D(2026,8,10,18,20), 7);
T('7.短nap后活体E≈8.4', l8.E, 8.3667);

// 8.阈值边界：4.9h 不足不重锚（累计E=4.2），5.0h 触发重锚（E=还欠2h）
var d8a=[
  {s:D(2026,8,9,22,0),e:D(2026,8,10,6,0)},
  {s:D(2026,8,10,20,0),e:D(2026,8,11,0,54)}    // 4.9h
];
var l9=computeEAtLive(d8a, D(2026,8,11,0,54), 7);
T('8.睡4.9h不重锚 累计E=4.2', l9.E, 4.2);
var d8b=[
  {s:D(2026,8,9,22,0),e:D(2026,8,10,6,0)},
  {s:D(2026,8,10,20,0),e:D(2026,8,11,1,0)}     // 5.0h
];
var l10=computeEAtLive(d8b, D(2026,8,11,1,0), 7);
T('8.睡5.0h重锚 E=2(欠2h)', l10.E, 2);

// 9.anchorH 可调：同样的5h觉，阈值调到7就不重锚（累计E=4）；阈值降到4时4h觉也重锚（E=还欠3h）
var l11=computeEAtLive(d8b, D(2026,8,11,1,0), 7, 7);
T('9.anchorH=7 时 5h 不重锚 E=4', l11.E, 4);
var l12=computeEAtLive([{s:D(2026,8,10,0,0),e:D(2026,8,10,4,0)}], D(2026,8,10,4,0), 7, 4);
T('9.anchorH=4 时 4h 也重锚 E=3', l12.E, 3);

TS('L15.9=正常', levelOf(15.9,L).name, '正常');
TS('L16=疲劳', levelOf(16,L).name, '疲劳');
TS('L19.9=疲劳', levelOf(19.9,L).name, '疲劳');
TS('L20=很累', levelOf(20,L).name, '很累');
TS('L23.9=很累', levelOf(23.9,L).name, '很累');
TS('L24=极限', levelOf(24,L).name, '极限');
TS('H20.5=20:30', fmtHour(20.5), '20:30');
TS('H0=00:00', fmtHour(0), '00:00');
TS('H23.98=23:59', fmtHour(23.98), '23:59');
TS('H23.999=00:00', fmtHour(23.999), '00:00');

if(__fails>0){ WScript.Echo('== '+__fails+' FAILED =='); WScript.Quit(1); }
else { WScript.Echo('== ALL PASS =='); }
'@
Write-TestFile "$root\_coretest.js" ($core + $test)
Write-Output '--- 1) CORE functional test ---'
$o1 = Run-Cscript "$root\_coretest.js"
Write-Output $o1
if($o1 -match 'ALL PASS'){ Write-Output '  [OK]' } else { $allOk=$false; Write-Output '  [FAILED]' }

# ============ 2) 整个 <script> 语法检查 ============
$sm = [regex]::Match($html, '(?s)<script>(.*?)</script>')
if(-not $sm.Success){ Write-Error 'script block not found'; exit 1 }
$appScript = $sm.Groups[1].Value
Write-TestFile "$root\_syncheck.js" $appScript
Write-Output '--- 2) full-script parse/run check ---'
$o2 = Run-Cscript "$root\_syncheck.js"
Write-Output $o2
if($o2 -match 'Microsoft JScript'){ $allOk=$false; Write-Output '  [FAILED]' } else { Write-Output '  [OK]' }

# ============ 3) DOM 冒烟 ============
$stub    = Get-Content -Raw -Encoding UTF8 "$root\tools\smoke-stub.js"
$harness = Get-Content -Raw -Encoding UTF8 "$root\tools\smoke-harness.js"
Write-TestFile "$root\_smoke.js" ($stub + $appScript + $harness)
Write-Output '--- 3) DOM smoke test ---'
$o3 = Run-Cscript "$root\_smoke.js"
Write-Output $o3
if($o3 -match 'DOM SMOKE OK'){ Write-Output '  [OK]' } else { $allOk=$false; Write-Output '  [FAILED]' }

Remove-Item "$root\_coretest.js","$root\_syncheck.js","$root\_smoke.js","$root\_dbg.js" -ErrorAction SilentlyContinue

if(-not $allOk){ Write-Output '== SOME CHECKS FAILED =='; exit 1 }
Write-Output '== ALL CHECKS OK =='
