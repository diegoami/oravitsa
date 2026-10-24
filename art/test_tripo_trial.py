"""Offline checks for the parts that prevent accidental repeated charges."""
import json
import tempfile
import unittest
from pathlib import Path
from tripo_trial import submit_once


class FakeClient:
    def __init__(self,balance=30,fail=False):
        self.balance=balance;self.fail=fail;self.uploads=0;self.generations=0
    def request(self,path,payload=None):
        if path=="/account/balance": return {"balance":self.balance}
        self.generations+=1
        if self.fail: raise TimeoutError("Response lost after server received request")
        return {"task_id":"task_test"}
    def upload(self,path):
        self.uploads+=1;return "file_test"


class TrialTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output=Path(self.temp.name)
        self.source=self.output/"source.png";self.source.write_bytes(b"reference")
        self.plan={"source_sha256":"test-hash","request":{"model":"test"}}
    def test_insufficient_credit_does_not_upload_or_submit(self):
        client=FakeClient(balance=29)
        with self.assertRaises(RuntimeError): submit_once(client,self.source,self.output,self.plan)
        self.assertEqual((client.uploads,client.generations),(0,0))
    def test_lost_response_cannot_trigger_second_paid_request(self):
        client=FakeClient(fail=True)
        with self.assertRaises(TimeoutError): submit_once(client,self.source,self.output,self.plan)
        with self.assertRaises(RuntimeError): submit_once(client,self.source,self.output,self.plan)
        self.assertEqual((client.uploads,client.generations),(1,1))
    def test_saved_task_is_reused(self):
        client=FakeClient()
        self.assertEqual(submit_once(client,self.source,self.output,self.plan),"task_test")
        self.assertEqual(submit_once(client,self.source,self.output,self.plan),"task_test")
        self.assertEqual((client.uploads,client.generations),(1,1))
    def test_reference_change_does_not_reuse_wrong_task(self):
        (self.output/"submission.json").write_text(json.dumps({"task_id":"task_old","source_sha256":"different"}))
        client=FakeClient()
        with self.assertRaises(RuntimeError): submit_once(client,self.source,self.output,self.plan)
        self.assertEqual((client.uploads,client.generations),(0,0))


if __name__=="__main__": unittest.main()
