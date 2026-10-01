# Zombie Defense Web

플레이: https://sanypower90-ops.github.io/zombie-defense-web/

## V7 무기·이동·바닥 업데이트

- 장검 사거리 5.5 → 7.15 (+30%). 푸른 반달 베기 효과만 표시합니다.
- 주먹 사거리 1.8 → 2.34 (+30%). 전진하는 주먹 효과가 최대 1.5배 커지면서 사라집니다.
- 권총·샷건·SMG·라이플·LMG·유탄·화염방사기·스나이퍼·로켓·레이저의 잡고 있는 모습을 각각 변경했습니다.
- 생성된 그림은 실제 연결된 개체 경계로 자르고, 옷의 허리를 걷는 다리에 맞춥니다.
- 이동 가속과 감속을 적용하고 이동 거리에 따라 걷는 프레임을 바꿉니다.
- 어두운 아스팔트 바닥과 도로에 생성된 질감을 적용했습니다.

## 검증

GitHub Actions에서 Godot 4.7.2로 리소스를 가져오고 아래 8개 검사를 통과한 뒤 웹으로 내보내고 배포합니다.

`smoke_test`, `sprite_visuals_test`, `ability_effects_test`, `ability_combat_test`, `boss_hit_test`, `orbit_range_test`, `ability_roles_test`, `melee_ground_test`.

이미지 생성 프롬프트: [output/v7-art-prompts.md](output/v7-art-prompts.md).
