import Testing
@testable import LevainCore

@Suite("르방 빌드 계산기")
struct LevainBuildTests {
    @Test("르방 200g(100%)을 종 20g(100%)으로 — 밀가루 90 + 물 90 (CLAUDE.md 예시)")
    func liquideBuild() throws {
        let b = try solveLevainBuild(
            LevainBuildSpec(targetGrams: 200, targetHydration: 1, chefGrams: 20, chefHydration: 1)
        ).get()
        #expect(abs(b.flour - 90) < 1e-9)
        #expect(abs(b.water - 90) < 1e-9)
        #expect(abs(b.total - 200) < 1e-9)
        let r = try #require(b.ratio)
        #expect(abs(r.flour - 4.5) < 1e-9 && abs(r.water - 4.5) < 1e-9)  // 1 : 4.5 : 4.5
    }

    @Test("뒤흐 르방 300g(50%)을 리퀴드 종 30g(100%)으로 — 종의 수분이 반영된다")
    func durFromLiquideChef() throws {
        // F = 200, W = 100 ; 종 Fc = 15, Wc = 15 → 밀가루 185, 물 85
        let b = try solveLevainBuild(
            LevainBuildSpec(targetGrams: 300, targetHydration: 0.5, chefGrams: 30, chefHydration: 1)
        ).get()
        #expect(abs(b.flour - 185) < 1e-9)
        #expect(abs(b.water - 85) < 1e-9)
    }

    @Test("종이 너무 많으면 최대 허용량을 알려준다")
    func chefTooLarge() {
        // L=100 h=1 → W=50 ; 종 hc=1 이면 C·0.5 ≤ 50 → C ≤ 100 (밀가루 한도도 100)
        let r = solveLevainBuild(
            LevainBuildSpec(targetGrams: 100, targetHydration: 1, chefGrams: 150, chefHydration: 1))
        guard case .failure(.chefTooLarge(let maxC)) = r else {
            Issue.record("chefTooLarge 오류가 나야 한다")
            return
        }
        #expect(abs(maxC - 100) < 1e-9)
        // 한도값으로는 성공 (밀가루·물 0)
        let ok = try? solveLevainBuild(
            LevainBuildSpec(targetGrams: 100, targetHydration: 1, chefGrams: maxC, chefHydration: 1)
        ).get()
        #expect(ok != nil && abs(ok!.flour) < 1e-9 && abs(ok!.water) < 1e-9)
        // 뒤흐 목표를 리퀴드 종으로: 물 한도가 먼저 걸린다 — L=150 h=0.5 → F=100 W=50, hc=1 → C ≤ 100
        let r2 = solveLevainBuild(
            LevainBuildSpec(targetGrams: 150, targetHydration: 0.5, chefGrams: 120, chefHydration: 1))
        if case .failure(.chefTooLarge(let m)) = r2 { #expect(abs(m - 100) < 1e-9) } else { Issue.record("한도") }
    }
}

@Suite("물 온도 (DDT) 계산기")
struct WaterTemperatureTests {
    @Test("르방 포함: 25×4 − (22+24+24+6) = 24°C")
    func withLevain() {
        let t = solveWaterTemperature(
            WaterTemperatureSpec(
                desiredDoughTemp: 25, flourTemp: 22, roomTemp: 24, levainTemp: 24, frictionFactor: 6))
        #expect(abs(t - 24) < 1e-9)
    }

    @Test("르방 없음(이스트 반죽): 26×3 − (20+22+2) = 34°C")
    func withoutLevain() {
        let t = solveWaterTemperature(
            WaterTemperatureSpec(desiredDoughTemp: 26, flourTemp: 20, roomTemp: 22, frictionFactor: 2))
        #expect(abs(t - 34) < 1e-9)
    }

    @Test("한여름: 필요 물 온도가 0°C 아래로 내려갈 수 있다 (얼음 필요 신호)")
    func summer() {
        let t = solveWaterTemperature(
            WaterTemperatureSpec(
                desiredDoughTemp: 24, flourTemp: 30, roomTemp: 32, levainTemp: 30, frictionFactor: 8))
        #expect(t < 0)
    }
}

@Suite("온도 단위 (°C 저장 · °F 표시)")
struct TemperatureUnitTests {
    @Test("절대 온도는 ×1.8 + 32, 온도 차(마찰계수)는 ×1.8만 — 왕복하면 원래 값")
    func conversions() {
        #expect(abs(fahrenheit(fromCelsius: 25) - 77) < 1e-9)
        #expect(abs(fahrenheit(fromCelsius: 0) - 32) < 1e-9)
        #expect(abs(fahrenheit(fromCelsius: 40) - 104) < 1e-9)
        #expect(abs(celsius(fromFahrenheit: 77) - 25) < 1e-9)
        #expect(abs(fahrenheitDelta(fromCelsius: 2) - 3.6) < 1e-9)
        #expect(abs(fahrenheitDelta(fromCelsius: 8) - 14.4) < 1e-9)
        #expect(abs(celsiusDelta(fromFahrenheit: 3.6) - 2) < 1e-9)
        for c in [-10.0, 0, 4, 22.5, 26, 40] {
            #expect(abs(celsius(fromFahrenheit: fahrenheit(fromCelsius: c)) - c) < 1e-9)
            #expect(abs(celsiusDelta(fromFahrenheit: fahrenheitDelta(fromCelsius: c)) - c) < 1e-9)
        }
    }

    @Test("°F로 바꾼 입력으로 풀어도 °C 결과를 °F로 바꾼 값과 같다 — 르방 유무 모두, 마찰계수는 차이로 환산")
    func solveInFahrenheit() {
        for levain in [24.0, nil] as [Double?] {
            for friction in [2.0, 8, 0] {
                let c = WaterTemperatureSpec(
                    desiredDoughTemp: 25, flourTemp: 22, roomTemp: 24, levainTemp: levain,
                    frictionFactor: friction)
                let f = WaterTemperatureSpec(
                    desiredDoughTemp: fahrenheit(fromCelsius: c.desiredDoughTemp),
                    flourTemp: fahrenheit(fromCelsius: c.flourTemp),
                    roomTemp: fahrenheit(fromCelsius: c.roomTemp),
                    levainTemp: c.levainTemp.map { fahrenheit(fromCelsius: $0) },
                    frictionFactor: fahrenheitDelta(fromCelsius: c.frictionFactor))
                let expected = fahrenheit(fromCelsius: solveWaterTemperature(c))
                #expect(abs(solveWaterTemperature(f) - expected) < 1e-9)

                // 마찰계수를 절대 온도처럼(+32) 바꾸면 32°F 어긋난다
                var wrong = f
                wrong.frictionFactor = fahrenheit(fromCelsius: c.frictionFactor)
                #expect(abs(solveWaterTemperature(wrong) - (expected - 32)) < 1e-9)
            }
        }
    }
}
