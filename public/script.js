const form = document.getElementById('form');
const chat = document.getElementById('chat');
const queryInput = document.getElementById('query');

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  const q = queryInput.value;
  queryInput.value = '';
  
  appendMsg(q, 'user');
  const botMsgId = 'msg-' + Date.now();
  appendMsg('Thinking...', 'bot', false, botMsgId);

  const res = await fetch('/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: q })
  });
  
  const data = await res.json();
  const div = document.getElementById(botMsgId);
  
  let botHTML = data.answer.replace(/\n/g, '<br/>');
  if (data.sources && data.sources.length > 0) {
    const uniqueSources =[...new Set(data.sources.map(s => s.source))].join(', ');
    botHTML += `<div class="source"><b>Sources:</b> ${uniqueSources}</div>`;
  }
  
  div.innerHTML = botHTML;
  chat.scrollTop = chat.scrollHeight;
});

function appendMsg(text, sender, isHTML = false, id = null) {
  const div = document.createElement('div');
  div.className = 'msg ' + sender;
  if (id) div.id = id;
  if (isHTML) div.innerHTML = text;
  else div.innerText = text;
  
  chat.appendChild(div);
  chat.scrollTop = chat.scrollHeight;
}