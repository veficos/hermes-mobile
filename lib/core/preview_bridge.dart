import 'dart:convert';
import 'dart:math';

const double kPreviewMinHeight = 120;
const double kPreviewMaxHeight = 1200;
const double kPreviewDefaultHeight = 280;
const int kPreviewMaxIntentLength = 500;
const int kPreviewMaxConsoleLength = 4000;

const String _bridgeChannel = 'HermesPreviewBridge';
const String _sizeMessageType = 'hermes-inline-preview-size';
const String _intentMessageType = 'hermes-inline-preview-intent';
const String _consoleMessageType = 'hermes-inline-preview-console';

enum PreviewBridgeEventKind { size, intent, console }

class PreviewBridgeEvent {
  const PreviewBridgeEvent._({
    required this.kind,
    this.height,
    this.width,
    this.prompt,
    this.level,
    this.message,
  });

  const PreviewBridgeEvent.size({required double height, required double width})
    : this._(kind: PreviewBridgeEventKind.size, height: height, width: width);

  const PreviewBridgeEvent.intent(String prompt)
    : this._(kind: PreviewBridgeEventKind.intent, prompt: prompt);

  const PreviewBridgeEvent.console({
    required String level,
    required String message,
  }) : this._(
         kind: PreviewBridgeEventKind.console,
         level: level,
         message: message,
       );

  final PreviewBridgeEventKind kind;
  final double? height;
  final double? width;
  final String? prompt;
  final String? level;
  final String? message;
}

String createPreviewBridgeToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(18, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

double? parsePreviewHeight(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) return null;
  return parsed
      .clamp(kPreviewMinHeight.toInt(), kPreviewMaxHeight.toInt())
      .toDouble();
}

PreviewBridgeEvent? parsePreviewBridgeMessage(String raw, String token) {
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map || decoded['token'] != token) return null;
  final type = decoded['type'];
  if (type == _sizeMessageType) {
    final height = decoded['height'];
    final width = decoded['width'];
    if (height is! num || !height.isFinite || height <= 0) return null;
    final safeWidth = width is num && width.isFinite && width > 0
        ? width.roundToDouble()
        : 0.0;
    return PreviewBridgeEvent.size(
      height: height.roundToDouble().clamp(
        kPreviewMinHeight,
        kPreviewMaxHeight,
      ),
      width: safeWidth,
    );
  }
  if (type == _intentMessageType) {
    final value = decoded['prompt'];
    if (value is! String) return null;
    final prompt = value.trim();
    if (prompt.isEmpty) return null;
    return PreviewBridgeEvent.intent(
      prompt.length <= kPreviewMaxIntentLength
          ? prompt
          : prompt.substring(0, kPreviewMaxIntentLength),
    );
  }
  if (type == _consoleMessageType) {
    final value = decoded['message'];
    if (value is! String || value.isEmpty) return null;
    final rawLevel = decoded['level']?.toString().toLowerCase() ?? 'log';
    final level =
        const {'log', 'info', 'warn', 'error', 'debug'}.contains(rawLevel)
        ? rawLevel
        : 'log';
    return PreviewBridgeEvent.console(
      level: level,
      message: value.length <= kPreviewMaxConsoleLength
          ? value
          : value.substring(0, kPreviewMaxConsoleLength),
    );
  }
  return null;
}

/// Adds the local-preview-only bridge immediately before `</body>`.
///
/// The caller must never use this document for an arbitrary remote URL. The
/// channel lets agent-authored local HTML resize, report console output, and
/// submit a short hidden user intent through `window.hermes.send(prompt)`.
String withPreviewBridge(String document, String token) {
  final encodedToken = jsonEncode(token);
  final script =
      '''<script>(function(){
var token=$encodedToken;
function emit(value){try{$_bridgeChannel.postMessage(JSON.stringify(value))}catch(_){}}
function send(prompt){if(typeof prompt!=="string"||!prompt.trim())return false;
 emit({type:"$_intentMessageType",token:token,prompt:prompt.slice(0,$kPreviewMaxIntentLength)});return true}
var previous=window.hermes&&typeof window.hermes==="object"?window.hermes:{};
window.hermes=Object.assign(previous,{send:send});
addEventListener("click",function(event){var target=event.target;
 var element=target&&target.closest?target.closest("[data-hermes-send]"):null;
 if(element)send(element.getAttribute("data-hermes-send")||"")},true);
function valueText(value){if(typeof value==="string")return value;
 try{var seen=[];return JSON.stringify(value,function(_,item){if(item&&typeof item==="object"){
  if(seen.indexOf(item)>=0)return "[Circular]";seen.push(item)}return item})}catch(_){return String(value)}}
["log","info","warn","error","debug"].forEach(function(level){var original=console[level];
 console[level]=function(){var args=Array.prototype.slice.call(arguments);emit({type:"$_consoleMessageType",
 token:token,level:level,message:args.map(valueText).join(" ").slice(0,$kPreviewMaxConsoleLength)});
 if(typeof original==="function")return original.apply(console,args)}});
addEventListener("error",function(event){emit({type:"$_consoleMessageType",token:token,level:"error",
 message:String(event.message||event.error||"Script error").slice(0,$kPreviewMaxConsoleLength)})});
addEventListener("unhandledrejection",function(event){emit({type:"$_consoleMessageType",token:token,level:"error",
 message:("Unhandled promise rejection: "+valueText(event.reason)).slice(0,$kPreviewMaxConsoleLength)})});
var lastHeight=0,lastWidth=0;function measure(){var root=document.documentElement,body=document.body;
 var height=Math.max(root?root.scrollHeight:0,body?body.scrollHeight:0);var width=0;
 if(body){var children=body.children,left=Infinity,right=0;for(var i=0;i<children.length;i++){
  var rect=children[i].getBoundingClientRect();if(rect.width===0&&rect.height===0)continue;
  if(rect.left<left)left=rect.left;if(rect.right>right)right=rect.right}if(right>left)width=right-left}
 height=Math.ceil(height);width=Math.ceil(width);if(Math.abs(height-lastHeight)>1||Math.abs(width-lastWidth)>1){
  lastHeight=height;lastWidth=width;emit({type:"$_sizeMessageType",token:token,height:height,width:width})}}
if(typeof ResizeObserver==="function"){var observer=new ResizeObserver(measure);observer.observe(document.documentElement);
 if(document.body)observer.observe(document.body)}addEventListener("load",measure);measure()
})()</script>''';
  final bodyClose = RegExp(
    r'</body\s*>',
    caseSensitive: false,
  ).firstMatch(document);
  if (bodyClose == null) return '$document$script';
  return '${document.substring(0, bodyClose.start)}$script${document.substring(bodyClose.start)}';
}

/// Builds the self-contained DOM tour action executed in the live preview.
/// The payload is JSON encoded and never interpolated as JavaScript source.
String previewTourScript(Map<String, dynamic> action) {
  final payload = jsonEncode(action);
  return '''(() => {
const action=$payload;
const state=window.__hermesMobileTour||(window.__hermesMobileTour={steps:[],index:0});
const rootId="__hermes-mobile-tour";
function clear(){const old=document.getElementById(rootId);if(old)old.remove()}
function escapeCss(value){return typeof CSS!=="undefined"&&CSS.escape?CSS.escape(value):String(value).replace(/["\\\\]/g,"\\\\\$&")}
function labelOf(el){for(const name of ["aria-label","title","alt","placeholder"]){const value=el.getAttribute(name);if(value)return value}
 const value=String(el.textContent||"").trim().replace(/\\s+/g," ");return value.length>80?value.slice(0,77)+"...":value}
function stableSelector(el){const tour=el.getAttribute("data-tour");if(tour)return '[data-tour="'+escapeCss(tour)+'"]';
 if(el.id)return "#"+escapeCss(el.id);const test=el.getAttribute("data-testid");if(test)return '[data-testid="'+escapeCss(test)+'"]';
 const aria=el.getAttribute("aria-label");const byAria=aria?el.tagName.toLowerCase()+'[aria-label="'+escapeCss(aria)+'"]':"";
 return byAria&&document.querySelectorAll(byAria).length===1?byAria:""}
function positionalSelector(el){const path=[];let node=el;while(node&&node!==document.body&&path.length<8){if(node.id){path.unshift("#"+escapeCss(node.id));break}
 const parent=node.parentElement;const index=parent?Array.prototype.indexOf.call(parent.children,node):-1;
 path.unshift(node.tagName.toLowerCase()+(index>=0?":nth-child("+(index+1)+")":""));node=parent}return path.join(" > ")}
function visible(el){const r=el.getBoundingClientRect();return r.width>=4&&r.height>=4&&r.bottom>0&&r.top<innerHeight&&r.right>0&&r.left<innerWidth}
function targets(){const out=[],seen=new Set();function push(el){if(out.length>=150||seen.has(el)||!visible(el))return;const label=labelOf(el);if(!label)return;
 const stable=stableSelector(el),selector=stable||positionalSelector(el);let match=null;try{match=document.querySelector(selector)}catch(_){}if(!selector||match!==el)return;
 const r=el.getBoundingClientRect();seen.add(el);out.push({label:label,rect:[Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height)],
 role:el.getAttribute("role")||el.tagName.toLowerCase(),selector:selector,stable:!!stable})}
 ["[data-tour]","nav,main,aside,header,footer,[role],h1,h2,h3","a[href],button,input,select,textarea,[tabindex],[aria-label]"].forEach(function(query){
  document.querySelectorAll(query).forEach(push)});return out.sort(function(a,b){return Number(b.stable)-Number(a.stable)})}
function render(step,withControls){clear();let target=null;if(step.selector){try{target=document.querySelector(step.selector)}catch(_){}
 if(!target)return {success:false,error:"No element matches selector(s): "+step.selector,hint:"Re-scan with targets and prefer stable targets."};
 target.scrollIntoView({block:"center",inline:"nearest"})}
 const root=document.createElement("div");root.id=rootId;root.style.cssText="position:fixed;inset:0;z-index:2147483646;pointer-events:none;font-family:system-ui,sans-serif";
 const focus=document.createElement("div");focus.style.cssText="position:fixed;border:3px solid #5b8def;border-radius:8px;box-shadow:0 0 0 9999px rgba(0,0,0,.58);transition:all .18s ease";
 let rect=null;if(target){rect=target.getBoundingClientRect();focus.style.left=(rect.left-5)+"px";focus.style.top=(rect.top-5)+"px";
 focus.style.width=(rect.width+10)+"px";focus.style.height=(rect.height+10)+"px"}else{focus.style.display="none"}root.appendChild(focus);
 const pop=document.createElement("div");pop.style.cssText="position:fixed;pointer-events:auto;max-width:min(320px,calc(100vw - 32px));padding:14px;border-radius:8px;background:#fff;color:#171717;box-shadow:0 12px 36px rgba(0,0,0,.3);font-size:14px;line-height:1.4";
 if(rect){const top=Math.min(innerHeight-180,Math.max(16,rect.bottom+14));pop.style.left=Math.min(innerWidth-336,Math.max(16,rect.left))+"px";pop.style.top=top+"px"}
 else{pop.style.left="50%";pop.style.top="50%";pop.style.transform="translate(-50%,-50%)"}
 if(step.title){const title=document.createElement("div");title.style.cssText="font-weight:700;font-size:16px;margin-bottom:6px";title.textContent=String(step.title);pop.appendChild(title)}
 if(step.text){const text=document.createElement("div");text.textContent=String(step.text);pop.appendChild(text)}
 if(withControls){const controls=document.createElement("div");controls.style.cssText="display:flex;justify-content:flex-end;gap:8px;margin-top:12px";
 function button(label,handler,disabled){const item=document.createElement("button");item.textContent=label;item.disabled=disabled;item.style.cssText="border:1px solid #bbb;background:#f5f5f5;color:#171717;border-radius:6px;padding:6px 10px";item.onclick=handler;controls.appendChild(item)}
 button("Back",function(){if(state.index>0){state.index--;render(state.steps[state.index],true)}},state.index<=0);
 button(state.index>=state.steps.length-1?"Done":"Next",function(){if(state.index>=state.steps.length-1){state.steps=[];clear()}else{state.index++;render(state.steps[state.index],true)}},false);pop.appendChild(controls)}
 root.appendChild(pop);document.body.appendChild(root);return {success:true}}
const kind=String(action.action||action.kind||"stop").toLowerCase();
if(kind==="targets")return JSON.stringify({success:true,targets:targets(),title:document.title,url:location.href});
if(kind==="show"){state.steps=[];const result=render(action,false);return JSON.stringify(Object.assign({action:kind},result))}
if(kind==="start"){if(!Array.isArray(action.steps)||!action.steps.length)return JSON.stringify({success:false,error:"start needs a non-empty steps array."});
 state.steps=action.steps;state.index=Math.max(0,Math.min(state.steps.length-1,Number(action.step_index||action.startAt||0)));
 const result=render(state.steps[state.index],true);return JSON.stringify(Object.assign({action:kind,activeStep:state.index,steps:state.steps.length},result))}
if(kind==="next"||kind==="prev"){if(!state.steps.length)return JSON.stringify({success:false,error:"No tour is running - start one first."});
 if(kind==="next"&&state.index>=state.steps.length-1){state.steps=[];clear();return JSON.stringify({success:true,action:kind,done:true})}
 state.index=Math.max(0,Math.min(state.steps.length-1,state.index+(kind==="next"?1:-1)));const result=render(state.steps[state.index],true);
 return JSON.stringify(Object.assign({action:kind,activeStep:state.index},result))}
if(kind==="stop"){state.steps=[];clear();return JSON.stringify({success:true,action:kind})}
return JSON.stringify({success:false,error:"Unknown tour action: "+kind})
})()''';
}
