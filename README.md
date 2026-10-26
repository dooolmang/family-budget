# 우리집 가계부

아이폰 홈 화면에 앱처럼 설치해서 둘이 같이 쓰는 가계부 웹앱(PWA)이에요.
빌드 과정 없이 정적 파일 몇 개뿐이라 어디에든 올리면 돼요.

```
index.html            앱 전체 (화면 + 로직)
config.js             Supabase 주소·키 (비우면 데모 모드)
schema.sql            Supabase에 한 번 실행할 DB 스키마
manifest.webmanifest  홈 화면 앱 설정
sw.js                 오프라인 캐시
icons/                앱 아이콘
```

## 기능
- 월별 지출 입력 (카테고리, 금액, 메모, 날짜는 선택)
- 기본 카테고리: 고정지출 · 교통비 · 유류비 · 식비 · 기타 소비
- 카테고리 추가 · 이름/색 편집 · 순서 변경 · 삭제
- "고정지출"로 표시한 카테고리는 지난달 내역을 버튼 한 번으로 불러오기
- 최근 6개월 추이 차트 + 카테고리별 월평균
- 둘이 공유: 한 명이 입력하면 다른 폰에 실시간 반영
- 전체 내역 CSV 내보내기

## 1. 먼저 데모로 써보기
`config.js`를 비워둔 상태로 열면 데모 모드예요 (샘플 데이터, 이 기기에만 저장).

```bash
cd family-budget
python3 -m http.server 8000   # → http://localhost:8000
```

## 2. Supabase 설정 (공유용, 무료)
1. https://supabase.com 에서 새 프로젝트 만들기 (리전은 Seoul 추천)
2. **SQL Editor** → `schema.sql` 내용 전체 붙여넣고 **Run**
3. **Authentication → Sign In / Providers → Email**에서 *Confirm email*을 끄면
   가입 즉시 로그인돼요. (켜두면 메일 링크 확인 후 로그인)
4. **Project Settings → API**의 `Project URL`과 `anon public` 키를
   `config.js`에 붙여넣기

anon 키는 공개돼도 괜찮아요. 모든 테이블에 RLS가 걸려 있어서
같은 가계부 구성원만 데이터를 읽고 쓸 수 있어요.

## 3. 배포 (Vercel 예시)
```bash
npm i -g vercel
cd family-budget
vercel --prod
```
또는 GitHub에 올리고 Vercel/Netlify/Cloudflare Pages에서 저장소를 연결하면
푸시할 때마다 자동 배포돼요. 빌드 명령은 비워두고, 출력 폴더는 루트(`.`)로 두면 돼요.

## 4. 아이폰에 설치
1. 사파리로 배포 주소 열기
2. 공유 버튼 → **홈 화면에 추가**
3. 홈 화면 아이콘으로 실행 (주소창 없이 앱처럼 떠요)

## 5. 둘이 연결
1. 한 명이 회원가입 → **새 가계부 만들기**
2. 설정 탭의 **초대코드** 복사해서 전달
3. 다른 한 명이 회원가입 → **초대코드로 참여**

## 참고
- 홈 화면 앱과 사파리는 로그인 상태를 따로 저장해요. 홈 화면 아이콘으로 연 뒤 로그인하세요.
- Supabase 무료 플랜은 오래 접속이 없으면 프로젝트가 일시정지될 수 있어요.
  대시보드에서 다시 켜면 데이터는 그대로 있어요.
- 데이터 구조: `households`(가계부) · `members`(구성원) · `categories` · `entries`
  (`month`는 `'YYYY-MM'` 문자열, `amount`는 원 단위 정수)
