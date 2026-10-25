import tempfile
import unittest
from pathlib import Path
from fal_tripo_trial import submit_once


class FakeFal:
    def __init__(self,fail=False): self.calls=0;self.fail=fail
    def request(self,url,payload):
        self.calls+=1
        if self.fail: raise TimeoutError("Response lost after submission")
        return {"request_id":"test-id","status_url":"https://queue.fal.run/status","response_url":"https://queue.fal.run/result"}


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.source=self.root/"source.png";self.source.write_bytes(b"reference")
        self.plan={"source_sha256":"same","request":{"texture":True}}
    def test_resume_cannot_charge_again(self):
        client=FakeFal()
        first=submit_once(client,self.source,self.root,self.plan)
        self.assertEqual(submit_once(client,self.source,self.root,self.plan),first)
        self.assertEqual(client.calls,1)
    def test_lost_response_blocks_a_second_submission(self):
        client=FakeFal(True)
        with self.assertRaises(TimeoutError): submit_once(client,self.source,self.root,self.plan)
        with self.assertRaises(RuntimeError): submit_once(client,self.source,self.root,self.plan)
        self.assertEqual(client.calls,1)
    def test_changed_reference_is_rejected(self):
        client=FakeFal();submit_once(client,self.source,self.root,self.plan)
        with self.assertRaises(RuntimeError): submit_once(client,self.source,self.root,{**self.plan,"source_sha256":"new"})
        self.assertEqual(client.calls,1)


if __name__=="__main__": unittest.main()
