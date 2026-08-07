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
T('1.dev=+6', normDev(felt1, 22), 6);
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
T('5.dev=0不转慢', normDev((((timeOfDay(rd.anchor)+rd.E)%24)+24)%24, timeOfDay(D(2026,8,6,14,0))), 0);
TS('5.等级=极限', levelOf(rd.E,L).name, '极限');

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
