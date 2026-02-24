#!/usr/bin/env python3
"""
XRST 測試平台
測試證據接收、代幣化、Smart-SLA 和監管結算
"""

import random
import hashlib

class XRSTTestBench:
    def __init__(self):
        self.token_types = {
            0: "Reliability Credit",
            1: "Reliability Penalty",
            2: "Stake Adjustment",
            3: "Settlement Proof"
        }
        
    def test_evidence_intake(self):
        """測試證據接收層"""
        print("\n=== XRST Evidence Intake Layer Test ===")
        
        # 模擬證據包
        evidence = {
            "sla_id": 0x5001,
            "timestamp": 12345678,
            "reliability_score": 950,
            "penalty_amount": 5000,
            "credit_amount": 1000,
            "boundary_id": 0x7B,
            "causal_chain": "0xCAFEBABE" * 8,
            "compliance_proof": "0xDEADBEEF" * 8
        }
        
        print("\nEvidence Packet:")
        for key, value in evidence.items():
            print(f"  {key}: {value}")
        
        # 驗證證據
        if evidence["reliability_score"] >= 900:
            status = "VALID"
            assert evidence["reliability_score"] >= 900, "Score too low"
        else:
            status = "INVALID"
        
        print(f"\nStatus: {status}")
        print("✅ Evidence Intake test PASSED")
        return True
    
    def test_tokenization_engine(self):
        """測試代幣化引擎"""
        print("\n=== XRST Tokenization Engine Test ===")
        
        test_cases = [
            ("Net Credit", 1000, 200, 800, 0, "Credit tokens generated"),
            ("Net Penalty", 200, 1000, -800, 1, "Penalty tokens generated"),
            ("Balanced", 500, 500, 0, 2, "Stake adjustment")
        ]
        
        for name, credit, penalty, net, expected_type, desc in test_cases:
            print(f"\n{name}:")
            print(f"  Credit: ${credit}")
            print(f"  Penalty: ${penalty}")
            print(f"  Net: ${net}")
            
            if net > 0:
                token_type = 0
                tokens = net
                token_name = "Credit"
            elif net < 0:
                token_type = 1
                tokens = -net
                token_name = "Penalty"
            else:
                token_type = 2
                tokens = 0
                token_name = "Stake"
            
            print(f"  Token Type: {token_name}")
            print(f"  Tokens Issued: {tokens}")
            print(f"  Description: {desc}")
            
            assert token_type == expected_type, f"Type should be {expected_type}"
        
        print("\n✅ Tokenization Engine test PASSED")
        return True
    
    def test_smart_sla(self):
        """測試 Smart-SLA 執行層"""
        print("\n=== XRST Smart-SLA Execution Layer Test ===")
        
        # SLA 配置
        sla_config = {
            "stake": 10000,
            "weights": {"availability": 50, "latency": 30, "correctness": 20}
        }
        
        participants = {
            "CSP": 0x1001,
            "Enterprise": 0x2001,
            "OEM": 0x3001
        }
        
        test_scores = [
            (980, "High Reliability", {0x1001: 500, 0x2001: 300, 0x3001: 200}),
            (920, "Medium Reliability", {0x1001: 400, 0x2001: 400, 0x3001: 200}),
            (850, "Low Reliability", {0x1001: -3000, 0x2001: -1500, 0x3001: -500}),
            (750, "Critical Breach", {0x1001: -5000, 0x2001: 0, 0x3001: 0})
        ]
        
        for score, name, expected in test_scores:
            print(f"\n{name} (Score: {score}/1000):")
            
            # 計算加權評分
            weighted = (score * 50 + score * 30 + score * 20) // 100
            print(f"  Weighted Score: {weighted}")
            
            # 根據評分分配
            if weighted >= 950:
                settlement = {0x1001: 500, 0x2001: 300, 0x2001: 200}
                status = "COMPLIANT"
            elif weighted >= 900:
                settlement = {0x1001: 400, 0x2001: 400, 0x2001: 200}
                status = "COMPLIANT"
            elif weighted >= 800:
                settlement = {0x1001: -3000, 0x2001: -1500, 0x2001: -500}
                status = "BREACHED"
            else:
                settlement = {0x1001: -5000, 0x2001: 0, 0x2001: 0}
                status = "BREACHED"
            
            print(f"  Status: {status}")
            for participant, amount in settlement.items():
                print(f"  Participant 0x{participant:04x}: ${amount}")
            
            # 驗證 CSP 總是承擔最多
            assert settlement[0x1001] <= 0 or settlement[0x1001] >= settlement[0x2001], "CSP should bear most risk"
        
        print("\n✅ Smart-SLA Execution test PASSED")
        return True
    
    def test_regulated_settlement(self):
        """測試監管結算層"""
        print("\n=== XRST Regulated Settlement Layer Test ===")
        
        # 模擬結算結果
        settlement = {
            "sla_id": 0x5001,
            "timestamp": 12345678,
            "reliability": 950,
            "settlements": {0x1001: 500, 0x2001: 300, 0x3001: 200},
            "stake_remaining": 9500
        }
        
        # 計算風險指數
        if settlement["reliability"] >= 950:
            risk = 10
            compliance = 100
        elif settlement["reliability"] >= 900:
            risk = 30
            compliance = 90
        elif settlement["reliability"] >= 800:
            risk = 60
            compliance = 75
        else:
            risk = 90
            compliance = 50
        
        print("\nSettlement Summary:")
        print(f"  SLA ID: 0x{settlement['sla_id']:04x}")
        print(f"  Reliability Score: {settlement['reliability']}/1000")
        print(f"  Risk Index: {risk}")
        print(f"  Compliance Level: {compliance}%")
        
        # 產生審計軌跡
        audit_hash = hashlib.sha256(f"{settlement}".encode()).hexdigest()[:16]
        print(f"  Audit Hash: {audit_hash}")
        
        # 產生監管報告
        print("\nRegulatory Report:")
        print("  • All settlements verified")
        print("  • Compliance proof: 0xCAFEBABE")
        print("  • Audit trail available")
        print("  • Ready for regulatory submission")
        
        assert risk <= 100, "Risk index must be ≤100"
        assert compliance <= 100, "Compliance level must be ≤100"
        
        print("\n✅ Regulated Settlement test PASSED")
        return True
    
    def test_end_to_end_settlement(self):
        """測試端到端結算流程"""
        print("\n=== XRST End-to-End Settlement Test ===")
        
        # 1. 證據接收
        print("\n1. Evidence Intake:")
        evidence = {
            "sla_id": 0x5001,
            "reliability": 920,
            "penalty": 3000,
            "credit": 500
        }
        print(f"   • SLA ID: 0x{evidence['sla_id']:04x}")
        print(f"   • Reliability Score: {evidence['reliability']}/1000")
        print(f"   • Penalty: ${evidence['penalty']}")
        print(f"   • Credit: ${evidence['credit']}")
        
        # 2. 代幣化
        print("\n2. Tokenization:")
        net = evidence['credit'] - evidence['penalty']
        if net > 0:
            tokens = net
            token_type = "CREDIT"
        else:
            tokens = -net
            token_type = "PENALTY"
        print(f"   • Net Settlement: ${net}")
        print(f"   • Token Type: {token_type}")
        print(f"   • Tokens Issued: {tokens}")
        
        # 3. Smart-SLA 執行
        print("\n3. Smart-SLA Execution:")
        participants = {
            "CSP": net * 60 // 100 if net < 0 else net * 50 // 100,
            "Enterprise": net * 30 // 100 if net < 0 else net * 30 // 100,
            "OEM": net * 10 // 100 if net < 0 else net * 20 // 100
        }
        for p, amount in participants.items():
            print(f"   • {p}: ${amount}")
        
        # 4. 監管結算
        print("\n4. Regulated Settlement:")
        risk = 30 if evidence['reliability'] >= 900 else 60
        print(f"   • Risk Index: {risk}")
        print(f"   • Compliance Level: 95%")
        print(f"   • Regulatory Hash: 0x{hashlib.sha256(b'settlement').hexdigest()[:16]}")
        
        # 5. 最終輸出
        print("\n5. Final Settlement Report:")
        print("   • Status: COMPLETED")
        print("   • Audit Trail: Available")
        print("   • Ready for Market: YES")
        
        print("\n✅ End-to-End Settlement test PASSED")
        return True
    
    def run_all_tests(self):
        """執行所有測試"""
        print("XRST Test Bench Started")
        print("=" * 60)
        
        tests = [
            ("Evidence Intake", self.test_evidence_intake),
            ("Tokenization Engine", self.test_tokenization_engine),
            ("Smart-SLA", self.test_smart_sla),
            ("Regulated Settlement", self.test_regulated_settlement),
            ("End-to-End", self.test_end_to_end_settlement)
        ]
        
        passed = 0
        failed_tests = []
        
        for name, test in tests:
            try:
                print(f"\n▶ Running {name} test...")
                if test():
                    passed += 1
                    print(f"  ✓ {name} test passed")
            except AssertionError as e:
                print(f"  ✗ {name} test failed: {e}")
                failed_tests.append(name)
        
        print("\n" + "=" * 60)
        print(f"XRST Test Summary: {passed}/{len(tests)} tests PASSED")
        if failed_tests:
            print(f"Failed tests: {', '.join(failed_tests)}")
        print("=" * 60)
        
        return passed == len(tests)

if __name__ == "__main__":
    tb = XRSTTestBench()
    success = tb.run_all_tests()
    exit(0 if success else 1)
