"""Protocol and image checks that support the opt-in native subtitle suite."""

import json
import socket
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path

from scripts.ci.mpv_subtitle_check import MpvIPC, sample_times
from scripts.ci.subtitle_fixture_suite import DEFAULT_MANIFEST, load_manifest
from scripts.ci.subtitle_pixels import assert_absent, assert_visible, compare_pngs


class _RunningProcess:
    def poll(self):
        return None


class NativeHarnessTest(unittest.TestCase):
    def test_ipc_pairs_response_ids_while_preserving_prior_events(self):
        client, server = socket.socketpair()
        ipc = MpvIPC.__new__(MpvIPC)
        ipc.socket = client
        ipc.process = _RunningProcess()
        ipc.condition = threading.Condition()
        ipc.responses = {}
        ipc.events = []
        ipc.sequence = 0
        ipc.request_id = 0
        ipc.reader_error = None
        ipc.reader = threading.Thread(target=ipc._read, daemon=True)
        ipc.reader.start()

        def respond():
            request = json.loads(server.recv(4096))
            server.sendall(b'{"event":"file-loaded"}\n')
            server.sendall(b'{"request_id":987,"error":"success","data":"other"}\n')
            server.sendall((json.dumps({'request_id': request['request_id'],
                                        'error': 'success', 'data': 'wanted'}) + '\n').encode())

        peer = threading.Thread(target=respond)
        peer.start()
        try:
            self.assertEqual(ipc.command('get_property', 'sid'), 'wanted')
            self.assertEqual(ipc.event_after('file-loaded', 0)[1]['event'],
                             'file-loaded')
            self.assertEqual(ipc.responses[987]['data'], 'other')
        finally:
            peer.join(timeout=2)
            server.shutdown(socket.SHUT_RDWR)
            server.close()
            client.close()
            ipc.reader.join(timeout=2)

    def test_pixel_comparison_detects_missing_and_lingering_caption(self):
        with tempfile.TemporaryDirectory(prefix='vpfl-pixel-test-') as folder:
            directory = Path(folder)
            plain = directory / 'plain.png'
            caption = directory / 'caption.png'
            for target, filter_graph in [
                (plain, 'color=c=0x203050:s=64x36:r=1'),
                (caption, 'color=c=0x203050:s=64x36:r=1,drawbox=x=20:y=22:w=24:h=10:color=white:t=fill'),
            ]:
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'lavfi',
                                '-i', filter_graph, '-frames:v', '1',
                                str(target)], check=True, timeout=15)
            empty = compare_pngs(plain, plain)
            visible = compare_pngs(caption, plain)
            self.assertEqual(empty['changed_pixels'], 0)
            self.assertGreater(visible['regions']['bottom'], 120)
            assert_absent(empty, 'blank control')
            assert_visible(visible, 'caption', region='bottom')
            with self.assertRaisesRegex(AssertionError, 'caption missing'):
                assert_visible(empty, 'missing')
            with self.assertRaisesRegex(AssertionError, 'persist'):
                assert_absent(visible, 'lingering')

    def test_manifest_times_include_true_gap_after_overlapping_cues(self):
        manifest = load_manifest(DEFAULT_MANIFEST)
        overlap = next(source for source in manifest['sources']
                       if source['id'] == 'overlap')
        points = sample_times(overlap)
        self.assertTrue(any(cue[0] <= points['first'] < cue[1]
                            for cue in overlap['cues']))
        self.assertFalse(any(cue[0] <= points['gap'] < cue[1]
                             for cue in overlap['cues']))
        self.assertGreater(points['gap'], overlap['cues'][1][1])


if __name__ == '__main__':
    unittest.main()
