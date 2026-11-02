# SMB 저장 응답 지연 조사용 Bambu Studio 포크

3MF 저장 시 숨겨진 홈 화면의 최근 프로젝트 목록 전체를 동기적으로 조회하는 비용을 줄이는 실험용 수정입니다. 긴 SMB 최근 기록이 있는 환경에서 저장 후 지연에 기여하는 경로를 확인했습니다. 저장창 자체의 간헐적인 멈춤은 별도로 조사하고 있습니다.

- [상류 검토 요청 PR #12850](https://github.com/bambulab/BambuStudio/pull/12850)
- [Windows 시험용 빌드](https://github.com/mk0000001/BambuStudio/releases/tag/smb-save-test-2026-11-02)
- [상류 제출용 코드 브랜치](https://github.com/mk0000001/BambuStudio/tree/fix/smb-save-recent-refresh)
- [Windows 전체 빌드와 회귀 테스트](https://github.com/mk0000001/BambuStudio/actions/runs/41323002157)
- [원인 분석·측정·검증 결과](docs/superpowers/investigations/2026-11-02-smb-validation.md)
- [측정 데이터](docs/superpowers/investigations/2026-11-02-smb-validation-results.json)
- [승인된 설계](docs/superpowers/specs/2026-11-01-smb-save-responsiveness-design.md)
- [구현 계획과 진행 상태](docs/superpowers/plans/2026-11-02-smb-save-responsiveness.md)

Windows와 Linux에서 Catch2 회귀 테스트 6개, assertion 21개가 통과했고 전체 Windows 앱 빌드도 성공했습니다. 241개 SMB 기록을 둔 합성 모델 시험에서 패치 버전의 수정 후 로컬 Ctrl+S는 첫 UI 확인인 0.64초 시점에 응답했습니다. 기준 버전은 3.2초에 접근 불가, 5.3초에 응답 회복이 관찰됐습니다. 이 수치는 자동화 오버헤드를 포함한 UI 접근성 확인 시점입니다.

SMB 드라이브·UNC 저장, ZIP/XML 무결성, 모델 개수, 다시 열기, 썸네일·시각·누락 파일 표시, 최소화/복원을 확인했습니다. 온라인 하위 웹뷰 전환과 macOS/Linux GUI는 미검증입니다. 저장창 자체의 긴 멈춤은 이번 추적에서 재현되지 않았습니다. 다음 공식 버전 반영 여부는 Bambu Studio 유지관리자가 결정합니다.

테스트용 앱은 `--datadir`로 별도 설정 폴더를 지정해 실행합니다. 원본 프로젝트를 덮어쓰지 말고 복사본이나 합성 모델을 사용하세요. 측정용 원시 ETL과 실제 최근 파일 경로는 공개 저장소에 포함하지 않습니다.

시험 ZIP의 SHA256: `6200ba17a8d865645ccc22f6b520284f37a1d06247617e3b36361374f93f44cf`.
