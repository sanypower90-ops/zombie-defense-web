# Zombie Defense 100

Godot 4.7.2 기반의 **3D 쿼터뷰 좀비 슈팅 디펜스** 프로젝트입니다.

공개 플레이: https://sanypower90-ops.github.io/zombie-defense-web/ (GitHub Pages 배포가 완료된 뒤 최신 버전으로 갱신됩니다.)

## 이번 통합 버전

- 제공된 Godot 프로젝트를 기반으로 5장의 고해상도 콘셉트 시트를 `assets/concept/`에 포함했습니다. 메인 메뉴의 **3D 캐릭터·무기 콘셉트 시트** 버튼에서 볼 수 있습니다.
- 플레이어 오렌지 안전 재킷, 좀비별 장비와 색상, 권총·화염방사기 외형, 구급상자·방탄판 등의 아이템, 파란 자동차·가판대·도로 방호벽·교통콘·가로등·상자를 실제 3D 도형으로 구성했습니다.
- 회색 바닥에 도로와 차선·경계선을 추가해 쿼터뷰 거리 형태를 더 분명하게 만들었습니다.
- 첫 번째 좀비 처치에서는 화염방사기, 두 번째 처치에서는 회복 아이템이 확정으로 떨어집니다.
- 특수무기 탄약을 모두 사용하면 다른 특수무기가 남아 있어도 기본 권총으로 돌아갑니다. 새 좀비가 해금되는 라운드의 첫 일반 출현은 해당 종류로 고정됩니다.
- 콘셉트 PNG는 3D 메시가 아닙니다. 실제 플레이 중 캐릭터와 기물은 가벼운 절차형 3D 모델이며, 향후 리깅된 `.glb` 모델로 교체할 수 있습니다.

## 현재 구현된 핵심 규칙

- 총 100라운드, 라운드당 30초.
- 30초 생존 시 다음 라운드로 즉시 진행하며 이전 라운드 좀비는 누적되지 않음.
- 기본 권총: 탄약 무제한, 12발 탄창 + 1초 재장전.
- 특수무기: 최근 2개만 보관. 탄약이 0이 되면 슬롯에서 제거하고 기본 권총으로 복귀.
- 같은 특수무기 재획득 시 해당 무기의 탄약을 최대치까지 충전하고 가장 최근 무기로 갱신.
- 화염방사기 포함.
- 블루 레이저 캐논: 5발, 직선 완전 관통, 단발 기준 최고 대미지.
- 라운드 11 / 21 / 31 / 51 / 61 / 71 / 81 / 91에서 **좀비 총 스폰 수가 누적 30% 상향**.
- 100라운드의 **총 적 출현 수(최종 보스 포함)**는 99라운드의 정확히 3배.
- 좀비 HP/공격력/속도는 완만하게만 상승하며 주 난이도는 개체수/조합으로 증가.
- 라운드와 점수는 **시작하기**를 누를 때 항상 1라운드·0점으로 초기화됩니다. 보관 아이템과 남은 특수무기는 같은 기기에 저장되어 다음 게임에서 다시 사용할 수 있습니다. 체크포인트 이어하기는 없습니다.
- 레벨업 시 3개 강화 중 1개 선택. 동일 계열 4단계에서 진화. 자석 계열은 아이템 자동 흡수 반경을 넓히고 최종 진화 시 경험치 +25%.
- 게임 종료 결과 화면에서 **랭킹 등록**을 누른 경우에만 Top 10 확인 후 닉네임 입력창 표시.
- Supabase 공용 데이터베이스를 사용해 모든 플레이어가 같은 Top 10을 봅니다. 연결이 끊어지면 로컬 랭킹을 대신 보여주지 않고 오류를 표시합니다.

## 조작

### PC
- `WASD` 또는 방향키: 이동
- WASD는 Godot의 **physical key** 판정으로 읽어 한글/영문 입력 상태와 무관하게 동작하도록 구성.
- 마우스: 조준
- 좌클릭: 사격
- `1`: 기본 권총
- `4`: 장검, `5`: 짧은 주먹 (기본 무기 3종은 **내 캐릭터** 화면에서도 선택 가능)
- `2`, `3`: 특수무기 슬롯
- 마우스 휠: 무기 순환
- `R`: 기본 권총 재장전

### 모바일 / 터치
- 화면 중앙 하단의 작은 원형 조이스틱을 한 손가락으로 드래그: 이동 방향과 사격 방향을 동시에 조작하고 자동 사격. 보이는 원은 기존 대비 70% 축소하고 터치 인식 영역은 넓게 유지했습니다. 제자리에서 누르고 있어도 주변 적을 향해 자동 사격합니다.
- 하단 버튼으로 기본총/특수무기 1/특수무기 2 선택 및 재장전.
- 오른쪽 위 `메뉴`에서 일시정지/계속하기와 내 캐릭터 화면을 선택할 수 있습니다.
- 세로 화면에서는 글씨와 버튼이 커지며 화면 전체를 사용합니다.
- 모바일 Web에서도 `InputEventScreenTouch`/`InputEventScreenDrag`를 직접 처리.

### 탄환 표시
- 일반 총탄은 히트스캔 판정을 유지하되, 화면에는 발사점에서 피격점까지 움직이는 발광 트레이서를 별도로 표시.
- 이전 버전보다 속도를 낮추고 길이/두께/잔상을 늘려 쿼터뷰에서도 총알 궤적을 확인하기 쉽게 조정.
- 유탄/로켓은 실제 발광 투사체가 목표점까지 이동한 뒤 폭발.
- 레이저는 파란 직선 빔을 별도 표시.

## Web 빌드

Web 타깃은 Godot `Compatibility` 렌더러와 싱글스레드 export를 사용합니다.
GitHub Pages 같은 정적 호스트에서 별도 COOP/COEP 헤더 없이 배포하기 위한 구성입니다.

Godot 4.7.2에서:

```bash
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
```

## 저장

보관 아이템·무기는 `user://checkpoint.json`에, 플레이어 이름은 `user://player_name.txt`에 저장됩니다. 파일명에 체크포인트가 남아 있어도 **라운드 이어하기 기능은 사용하지 않습니다**.
Web export에서는 `user://`가 브라우저 IndexedDB를 사용합니다. 로그인 없이 같은 브라우저에서 **내 캐릭터**의 보관 아이템을 확인하고 게임 중 사용할 수 있습니다.
시크릿 모드, 브라우저 데이터 삭제, 저장소 정책에 따라 데이터가 사라질 수 있습니다.

## 글로벌 랭킹·온라인 계정 준비 상태

공용 랭킹용 Supabase 프로젝트의 `leaderboard` 표와 RLS 정책은 `supabase/schema.sql`로 설정했고, 공개용 publishable key를 `config/leaderboard_config.gd`에 연결했습니다. 모든 플레이어는 같은 서버의 Top 10을 조회하고 게임 종료 후 점수를 등록합니다. 온라인 연결에 실패하면 오류를 표시하며 기기별 로컬 랭킹으로 바꾸지 않습니다.

GitHub Pages는 정적 파일 서비스이므로 비밀번호를 검증하거나 개인 데이터를 안전하게 보관하는 서버가 될 수 없습니다. `내 이름 설정`은 로그인 계정이 아니라 **이 기기에만 저장되는 이름**입니다.

이메일 없이 임의의 아이디와 비밀번호로 가입하려면 **별도의 계정 서버**가 필요합니다. Supabase의 기본 비밀번호 인증은 이메일 또는 전화번호 기반입니다. 따라서 현재 게임에서는 온라인 가입 버튼을 제공하지 않습니다. 계정 서버를 마련하기 전까지 아이템은 로그인 없이 로컬 저장으로 사용합니다. [GitHub Pages 설명](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages), [Supabase 비밀번호 인증](https://supabase.com/docs/guides/auth/passwords)

`service_role` 키는 절대 클라이언트 프로젝트에 넣지 않습니다.

현재 랭킹은 브라우저 클라이언트가 점수를 전송하는 구조이므로 완전한 치트 방지는 불가능합니다. 경쟁형 랭킹으로 운영하려면 Edge Function/서버 검증을 추가해야 합니다. 계정 저장 RLS는 [Supabase 공식 가이드](https://supabase.com/docs/guides/database/postgres/row-level-security)를 따릅니다.

## 홈 화면에 설치해 주소창 없이 실행

Web 내보내기를 PWA `standalone`으로 설정했습니다. 휴대폰 브라우저에서 게임 주소를 열고 **홈 화면에 추가/앱 설치**를 선택한 뒤 홈 아이콘으로 실행하면 주소창과 뒤로가기 바를 숨길 수 있습니다. 일반 브라우저 탭의 주소창을 게임 코드가 강제로 없앨 수는 없습니다. [Godot Web PWA 표시 모드 설명](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html)

## GitHub Pages

`deploy/github-pages-workflow.yml`을 새 게임 전용 GitHub 저장소의
`.github/workflows/pages.yml`로 복사하면 push 시 Godot 4.7.2 Web export + Pages 배포를 자동화할 수 있습니다.

Pages 설정에서 Source를 **GitHub Actions**로 선택해야 합니다.

## 제작 단계

현재 빌드는 시스템 검증용 vertical slice이며, 캐릭터/좀비/무기/맵 기물은 저사양 Web 테스트를 위해 상세 절차형 3D 프리미티브로 구성되어 있습니다.
완성 아트 교체 시 게임 로직은 그대로 유지할 수 있도록 분리되어 있습니다.

## Godot 4.7.2 compile compatibility patch
- Dynamic method results no longer use `:=` local type inference.
- Checkpoint load is explicitly typed as `Dictionary`.
- This fixes the parser error shown at `scripts/main.gd:385` (`Cannot infer the type of data variable...`) and the same class of inference errors in Player/Zombie/Pickup scripts.


## 레퍼런스 이미지와 실제 3D 에셋

`assets/reference/`의 PNG는 플레이어·좀비·무기·아이템·맵 기물의 **콘셉트/모델링 레퍼런스**입니다. PNG 캐릭터 시트 자체는 3D Mesh가 아니므로 Godot에서 캐릭터가 자동으로 해당 모습의 입체 모델로 변환되지는 않습니다.

실제 게임 화면을 레퍼런스와 동일한 외형으로 만들려면 `assets/models/`에 리깅/모델링된 `.glb`/`.gltf` 파일을 넣고 현재 절차형 프리미티브 비주얼을 교체해야 합니다. 현재 프로젝트는 게임 로직과 Web 실행 검증을 위해 경량 절차형 3D 비주얼을 fallback으로 사용합니다.
