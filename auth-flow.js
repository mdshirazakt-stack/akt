(function () {
  const CONSENT_VERSION = 'terms-2026-05-25';
  const ONBOARDING_DRAFT_KEY = 'akt_onboarding_draft_v1';
  const REQUIRED_CONSENT_SECTIONS = ['6', '7', '8', '18'];
  const ROLE_LEVELS = { visitor: 1, moderator: 2, admin: 3, superadmin: 4 };
  const WHATSAPP_COMMUNITY_URL = 'https://chat.whatsapp.com/HtSTOEqyDx644pLLdbnnlm';

  function escapeHtmlLocal(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  let sb = null;
  let callbacks = {};
  let currentSession = null;
  let currentVisitor = null;
  let initialized = false;
  let currentOnboardingStep = 1;
  let signupProgressTimer = null;
  const signupSessionId = (() => {
    const existing = sessionStorage.getItem('akt_signup_session_id');
    if (existing) return existing;
    const id = (window.crypto?.randomUUID && window.crypto.randomUUID()) || String(Date.now()) + '-' + Math.random().toString(16).slice(2);
    sessionStorage.setItem('akt_signup_session_id', id);
    return id;
  })();

  function normalizeAccessRole(role) {
    return ROLE_LEVELS[role] ? role : 'visitor';
  }

  function byId(id) {
    return document.getElementById(id);
  }

  function value(id) {
    return (byId(id)?.value || '').trim();
  }

  function checked(id) {
    return Boolean(byId(id)?.checked);
  }

  function normalizeMobile(input) {
    return String(input || '').replace(/\D/g, '').trim();
  }

  function getIpHint() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
    const lang = navigator.language || '';
    return [tz, lang, screen.width + 'x' + screen.height].filter(Boolean).join(' | ');
  }

  async function logSignupEvent(eventName, details = {}) {
    if (!sb || !eventName) return;
    const user = currentSession?.user || null;
    const snapshot = details.form_snapshot === undefined ? null : details.form_snapshot;
    const payload = {
      email: details.email || userEmail(user) || currentVisitor?.email || value('auth-email') || null,
      auth_user_id: user?.id || currentVisitor?.auth_user_id || null,
      visitor_id: details.visitor_id || currentVisitor?.id || null,
      event_name: eventName,
      stage: details.stage || (currentOnboardingStep ? 'onboarding' : 'signin'),
      step: details.step === undefined ? currentOnboardingStep : details.step,
      form_snapshot: snapshot || {},
      details: {
        ...details,
        signup_session_id: signupSessionId,
        page: location.pathname
      },
      ip_hint: getIpHint(),
      user_agent: navigator.userAgent
    };
    delete payload.details.form_snapshot;
    const { error } = await sb.from('signup_events').insert(payload);
    if (error && !/does not exist|schema cache|relation|permission|policy/i.test(error.message || '')) {
      console.warn('Signup event log failed:', error.message);
    }
  }

  function showMessage(message, isError = true) {
    const err = byId('auth-err');
    if (!err) return;
    err.textContent = message;
    err.style.color = isError ? '#c0392b' : '#2e6e4a';
    err.style.display = 'block';
  }

  function setNote(message) {
    const note = byId('auth-note');
    if (note) note.textContent = message;
  }

  function showPendingApprovalMessage() {
    const err = byId('auth-err');
    if (!err) return;
    setNote('');
    err.style.color = '#2e6e4a';
    err.style.display = 'block';
    err.innerHTML = `
      Thank you for registering. Your account is pending review by the site admin and is not
      active yet — you will not be able to view the archive until it is approved. This usually
      takes up to 24 hours. Please check back later by signing in again.
      <br><br>
      While you wait, please read
      <a href="trouble.html" target="_blank" rel="noopener" style="color:#2e6e4a;font-weight:700">Trouble Signing In?</a>
      to understand what to expect next and what to do if your profile isn't on the site yet.
    `;
  }

  // Blocked/rejected accounts cannot sign in at all — point them at the
  // Trouble Signing In page, which explains both statuses and how to
  // reach an admin if it looks like a mistake.
  function showBlockedMessage(status) {
    const err = byId('auth-err');
    if (!err) return;
    setNote('');
    err.style.color = '#c0392b';
    err.style.display = 'block';
    const verb = status === 'rejected' ? 'rejected' : 'blocked';
    err.innerHTML = `
      Your access is currently ${verb}. Please contact the administrator if this looks incorrect.
      <br><br>
      Please read
      <a href="trouble.html" target="_blank" rel="noopener" style="color:#2e6e4a;font-weight:700">Trouble Signing In?</a>
      for what this means and how to proceed.
    `;
  }

  // Look up an unread "your claim was revoked" notice for this visitor.
  // Admins create these (source_type = 'claim_revoked') via revokeProfileClaim()
  // in admin.html — but ONLY when the visitor had no other valid claim left
  // (a genuine wrong-profile case), never for routine duplicate-claim cleanup.
  async function getClaimRevokeNotice(visitor) {
    if (!visitor || !sb) return null;
    try {
      const email  = userEmail(currentSession?.user) || visitor?.email || '';
      const mobile = visitor?.mobile || '';
      const authId = currentSession?.user?.id || visitor?.auth_user_id || '';
      const clauses = [];
      if (authId)  clauses.push(`recipient_auth_uid.eq.${authId}`);
      if (email)   clauses.push(`recipient_email.ilike.${email}`);
      if (mobile)  clauses.push(`recipient_mobile.eq.${String(mobile).replace(/\D/g,'')}`);
      if (!clauses.length) return null;
      const { data, error } = await sb.from('user_notifications')
        .select('id,title,message,source_type,created_at')
        .eq('source_type', 'claim_revoked')
        .or(clauses.join(','))
        .is('shown_at', null)
        .order('created_at', { ascending: false })
        .limit(1);
      if (error || !data?.length) return null;
      return data[0];
    } catch { return null; }
  }

  // Blocking, must-acknowledge interstitial shown (once) right before a
  // visitor whose only claim was revoked is routed back into onboarding —
  // explains why, gives them a path forward, and a way to reach admins.
  // Rendered as HTML directly into #auth-err (the established "message view"
  // element) since showMessage() only supports plain text.
  function showClaimRevokedInterstitial(adminNote, onContinue) {
    const err = byId('auth-err');
    if (!err) { onContinue(); return; }
    setNote('');
    err.style.color = '#7a3a32';
    err.style.display = 'block';
    err.innerHTML = `
      <div style="text-align:left;background:#fff3f2;border:1px solid rgba(192,57,43,0.32);border-left:4px solid #c0392b;border-radius:6px;color:#7a3a32;font-size:0.82rem;line-height:1.6;padding:14px 16px">
        <strong style="color:#c0392b">Your previous profile claim was removed by the site admin.</strong>
        ${adminNote ? `<div style="margin-top:8px;font-style:italic">Admin note: "${escapeHtmlLocal(adminNote)}"</div>` : ''}
        <p style="margin:10px 0 0">To continue, please sign in again and claim the profile that genuinely belongs to you.</p>
        <p style="margin:8px 0 0">If your profile does not yet exist on the site, please contact the site admin <strong>within the next 3 days</strong> to have it created — accounts left unresolved beyond that may remain restricted.</p>
        <p style="margin:8px 0 0">Have any other issue to raise with the admins? Join our WhatsApp community: <a href="${WHATSAPP_COMMUNITY_URL}" target="_blank" rel="noopener" style="color:#2e6e4a;font-weight:700">Join WhatsApp Community</a></p>
        <div style="margin-top:14px;text-align:right">
          <button type="button" id="claim-revoke-ack-btn" style="background:#2e6e4a;border:1px solid #2e6e4a;color:#fff;cursor:pointer;font-family:'Lato',sans-serif;font-size:0.76rem;font-weight:700;letter-spacing:0.05em;padding:9px 16px;text-transform:uppercase">OK, continue</button>
        </div>
      </div>`;
    const btn = byId('claim-revoke-ack-btn');
    if (btn) btn.onclick = () => {
      err.style.display = 'none';
      err.innerHTML = '';
      err.style.color = '#c0392b';
      onContinue();
    };
  }

  function setView(view) {
    const gate = byId('auth-gate');
    const hasWarmSession = sessionStorage.getItem('akt_access_granted') === '1';
    const signIn = byId('auth-signin-panel');
    const form = byId('visitor-onboarding-form');
    const loading = byId('auth-loading');
    if (gate) gate.style.display = view === 'loading' && hasWarmSession ? 'none' : 'flex';
    if (gate) gate.dataset.authView = view;
    document.querySelector('.auth-shell')?.classList.toggle('onboarding-mode', view === 'onboarding');
    if (signIn) signIn.style.display = view === 'signin' ? 'block' : 'none';
    if (form) form.style.display = view === 'onboarding' ? 'grid' : 'none';
    if (loading) loading.style.display = view === 'loading' ? 'block' : 'none';
    if (view === 'onboarding') setOnboardingStep(1, false);
    const err = byId('auth-err');
    if (err && view !== 'message') err.style.display = 'none';
  }

  function redirectTo() {
    return window.location.href.split('#')[0];
  }

  function userEmail(user) {
    return (user?.email || user?.user_metadata?.email || '').trim();
  }

  function userName(user) {
    return (user?.user_metadata?.full_name || user?.user_metadata?.name || userEmail(user).split('@')[0] || '').trim();
  }

  async function findVisitorForUser(user) {
    // Use SECURITY DEFINER function to bypass RLS — critical for blocked users
    // whose auth_user_id may be null (RLS would block the direct table query,
    // making them appear as new users and bypass blocking).
    const { data, error } = await sb.rpc('get_my_visitor');
    if (!error && data) return data;

    // Fallback: direct table query (works if auth_user_id is already linked)
    const email = userEmail(user);
    let found = null;
    const { data: rows } = await sb.from('visitors')
      .select('*')
      .eq('auth_user_id', user.id)
      .order('last_seen', { ascending: false })
      .limit(1);
    if (rows && rows.length) found = rows[0];

    if (!found && email) {
      const { data: emailRows } = await sb.from('visitors')
        .select('*')
        .ilike('email', email)
        .order('last_seen', { ascending: false })
        .limit(1);
      if (emailRows && emailRows.length) found = emailRows[0];
    }
    return found;
  }

  function visitorStatus(visitor) {
    if (visitor?.is_blocked) return 'blocked';
    return visitor?.access_status || 'approved';
  }

  function isOnboardingComplete(visitor) {
    return Boolean(visitor?.visitor_form_completed && visitor?.consent_terms_accepted);
  }

  function fillOnboarding(user, visitor) {
    const draft = loadDraft();
    const name = value('visitor-name') || visitor?.name_entered || userName(user);
    const email = userEmail(user);
    if (byId('visitor-name')) byId('visitor-name').value = name || '';
    if (byId('visitor-email-display')) byId('visitor-email-display').textContent = email || 'Signed in';
    if (byId('visitor-mobile')) byId('visitor-mobile').value = visitor?.mobile || '';
    if (byId('visitor-father-name')) byId('visitor-father-name').value = visitor?.father_name || '';
    if (byId('visitor-root-place')) byId('visitor-root-place').value = visitor?.root_place || visitor?.family_reference || '';
    if (byId('visitor-current-place')) byId('visitor-current-place').value = visitor?.current_place || '';
    if (byId('visitor-current-address')) byId('visitor-current-address').value = visitor?.current_address || '';
    if (byId('visitor-oldest-ancestor')) byId('visitor-oldest-ancestor').value = visitor?.oldest_ancestor || '';
    if (byId('visitor-heard-source')) byId('visitor-heard-source').value = visitor?.heard_from_source || '';
    if (byId('visitor-heard-relative-name')) byId('visitor-heard-relative-name').value = visitor?.heard_from_relative_name || '';
    if (byId('visitor-heard-relative-place')) byId('visitor-heard-relative-place').value = visitor?.heard_from_relative_place || '';
    if (byId('visitor-heard-details')) byId('visitor-heard-details').value = visitor?.heard_from_details || '';
    if (draft) restoreDraft(draft);
    toggleHeardFromFields();
  }

  function onboardingFieldIds() {
    return [
      'visitor-name',
      'visitor-mobile',
      'visitor-father-name',
      'visitor-root-place',
      'visitor-current-place',
      'visitor-current-address',
      'visitor-oldest-ancestor',
      'visitor-heard-source',
      'visitor-heard-relative-name',
      'visitor-heard-relative-place',
      'visitor-heard-details'
    ];
  }

  function loadDraft() {
    try {
      return JSON.parse(sessionStorage.getItem(ONBOARDING_DRAFT_KEY) || 'null');
    } catch {
      return null;
    }
  }

  function restoreDraft(draft) {
    onboardingFieldIds().forEach(id => {
      if (draft[id] !== undefined && byId(id)) byId(id).value = draft[id];
    });
    REQUIRED_CONSENT_SECTIONS.forEach(section => {
      const id = 'consent-section-' + section;
      if (draft[id] !== undefined && byId(id)) byId(id).checked = Boolean(draft[id]);
    });
  }

  function saveDraft() {
    const draft = {};
    onboardingFieldIds().forEach(id => { if (byId(id)) draft[id] = byId(id).value; });
    REQUIRED_CONSENT_SECTIONS.forEach(section => {
      const id = 'consent-section-' + section;
      if (byId(id)) draft[id] = byId(id).checked;
    });
    sessionStorage.setItem(ONBOARDING_DRAFT_KEY, JSON.stringify(draft));
  }

  function bindDraftAutosave() {
    const form = byId('visitor-onboarding-form');
    if (!form || form.dataset.draftAutosaveBound === '1') return;
    form.dataset.draftAutosaveBound = '1';
    form.addEventListener('input', () => {
      saveDraft();
      scheduleSignupProgressLog();
    });
    form.addEventListener('change', () => {
      saveDraft();
      scheduleSignupProgressLog(250);
    });
  }

  function scheduleSignupProgressLog(delay = 1000) {
    clearTimeout(signupProgressTimer);
    signupProgressTimer = setTimeout(() => {
      logSignupEvent('onboarding_field_progress', {
        stage: 'onboarding',
        step: currentOnboardingStep,
        form_snapshot: formSnapshot()
      });
    }, delay);
  }

  let appLaunched = false; // guard against re-init on tab focus / token refresh

  async function redirectForGuideIfNeeded(visitor) {
    if (!visitor?.id || !sb) return false;

    // Already acknowledged — never show again
    const { data: ackRow } = await sb
      .from('visitor_onboarding_acknowledgements')
      .select('acknowledged_at')
      .eq('visitor_id', visitor.id)
      .maybeSingle();
    if (ackRow) return false;

    // Has an active profile claim — they've been through the process, skip guide.
    // Use .limit(1) not .maybeSingle() — visitor_id is not unique on profile_claims
    // (a user can have multiple rows), and .maybeSingle() errors on >1 row.
    // If the RLS read fails (null auth_user_id edge case), claims is null/empty
    // and we err on the side of showing the guide.
    const { data: claims } = await sb
      .from('profile_claims')
      .select('visitor_id')
      .eq('visitor_id', visitor.id)
      .limit(1);
    if (claims && claims.length > 0) return false;

    window.location.href = 'onboarding-guide.html';
    return true;
  }

  async function enterVisitor(visitor) {
    currentVisitor = visitor;
    const role = normalizeAccessRole(visitor?.access_role);
    const name = visitor?.name_entered || userName(currentSession?.user) || 'Visitor';
    const mobile = visitor?.mobile || '';
    const visitCount = Number(visitor?.visit_count || 0) + 1;
    const now = new Date().toISOString();
    const updatePayload = {
      last_seen: now,
      visit_count: visitCount,
      auth_user_id: currentSession?.user?.id || visitor?.auth_user_id || null,
      email: userEmail(currentSession?.user) || visitor?.email || null,
      ip_hint: getIpHint(),
      updated_at: now
    };
    // Start the 72h profile-claim clock on the visitor's first successful
    // entry into the archive (i.e. after admin approval), not at signup —
    // a user approved a week after registering still gets a fair window.
    // Set once; never overwritten on later logins.
    if (!visitor?.claim_clock_started_at) {
      updatePayload.claim_clock_started_at = now;
    }
    let { error: updateError } = await sb.from('visitors').update(updatePayload).eq('id', visitor.id);
    if (updateError && updatePayload.claim_clock_started_at && /schema cache|claim_clock_started_at/i.test(updateError.message || '')) {
      // supabase_claim_clock_login.sql hasn't been applied to this project
      // yet — retry without the new column so last_seen/visit_count/
      // auth_user_id/email still get recorded. claim_clock_started_at will
      // be set on this visitor's next login once the column exists.
      delete updatePayload.claim_clock_started_at;
      ({ error: updateError } = await sb.from('visitors').update(updatePayload).eq('id', visitor.id));
    }

    sessionStorage.setItem('akt_visitor_name', name);
    sessionStorage.setItem('akt_visitor_mobile', mobile);
    sessionStorage.setItem('akt_access_granted', '1');
    sessionStorage.setItem('akt_visitor_role', role);
    sessionStorage.setItem('akt_auth_user_id', currentSession?.user?.id || '');

    const updatedVisitor = { ...visitor, visit_count: visitCount, claim_clock_started_at: visitor?.claim_clock_started_at || updatePayload.claim_clock_started_at || null };
    if (typeof callbacks.onStart === 'function') {
      await callbacks.onStart(name, role, updatedVisitor);
    }
    appLaunched = true; // mark app as fully initialised
    await refreshProfileClaimBanner(updatedVisitor);
    await showPendingNotifications(visitor);
  }

  async function showPendingNotifications(visitor) {
    if (!visitor || !sb) return;
    try {
      const email  = userEmail(currentSession?.user) || visitor?.email || '';
      const mobile = visitor?.mobile || '';
      const authId = currentSession?.user?.id || visitor?.auth_user_id || '';

      const clauses = [];
      if (authId)  clauses.push(`recipient_auth_uid.eq.${authId}`);
      if (email)   clauses.push(`recipient_email.ilike.${email}`);
      if (mobile)  clauses.push(`recipient_mobile.eq.${String(mobile).replace(/\D/g,'')}`);
      if (!clauses.length) return;

      const { data: notes, error } = await sb.from('user_notifications')
        .select('id,title,message,source_type,created_at')
        .or(clauses.join(','))
        .is('shown_at', null)
        .order('created_at', { ascending: true })
        .limit(10);
      if (error || !notes?.length) return;

      // Mark all as shown immediately
      const ids = notes.map(n => n.id);
      sb.from('user_notifications')
        .update({ shown_at: new Date().toISOString() })
        .in('id', ids)
        .then(() => {});

      // Render one banner per notification (stacked)
      notes.forEach(n => renderNotificationBanner(n));
    } catch (e) { /* notifications are non-critical */ }
  }

  function renderNotificationBanner(note) {
    if (!document.getElementById('notification-banner-styles')) {
      const style = document.createElement('style');
      style.id = 'notification-banner-styles';
      style.textContent = `
        .akt-notification-banner {
          background: #f0fdf4; border: 1px solid rgba(46,110,74,0.35);
          border-left: 4px solid #2e6e4a; color: #1a3d2e;
          font-family: 'Lato', sans-serif;
          margin: 10px auto 0; max-width: min(1120px, calc(100% - 36px));
          padding: 13px 16px; display: flex; align-items: flex-start; gap: 12px;
        }
        .akt-notification-banner .notif-icon { font-size: 1.3rem; flex-shrink: 0; margin-top: 1px; }
        .akt-notification-banner .notif-body { flex: 1; }
        .akt-notification-banner .notif-title { font-size: 0.88rem; font-weight: 700; margin-bottom: 3px; }
        .akt-notification-banner .notif-msg   { font-size: 0.82rem; line-height: 1.55; color: #2e4a3a; }
        .akt-notification-banner .notif-close {
          background: none; border: none; cursor: pointer; font-size: 1.1rem;
          color: #5f7a6a; padding: 0 2px; flex-shrink: 0; line-height: 1;
        }
      `;
      document.head.appendChild(style);
    }

    const isQuery = note.source_type === 'correction_note';
    const banner = document.createElement('div');
    banner.className = 'akt-notification-banner';
    if (isQuery) {
      banner.style.cssText = 'background:#eff6ff;border-color:rgba(37,99,235,0.35);border-left-color:#2563eb;color:#1e3a5f;flex-direction:column;gap:10px;';
    }
    const replyFormId = 'notif-reply-' + note.id;
    banner.innerHTML = `
      <div style="display:flex;align-items:flex-start;gap:12px;width:100%">
        <span class="notif-icon">${isQuery ? '💬' : '✅'}</span>
        <div class="notif-body" style="flex:1">
          <div class="notif-title" style="${isQuery ? 'color:#1e40af' : ''}">${note.title.replace(/</g,'&lt;').replace(/>/g,'&gt;')}</div>
          <div class="notif-msg">${note.message.replace(/</g,'&lt;').replace(/>/g,'&gt;')}</div>
        </div>
        <button class="notif-close" type="button" aria-label="Acknowledge">Got it</button>
      </div>
      ${isQuery ? `
      <div id="${replyFormId}" style="width:100%;padding-top:10px;border-top:1px solid rgba(37,99,235,0.2)">
        <div style="font-size:0.76rem;font-weight:700;color:#1e40af;margin-bottom:6px">Your reply to the admin:</div>
        <textarea rows="2" style="width:100%;padding:8px 10px;border:1px solid #bfdbfe;background:#fff;font-family:inherit;font-size:0.84rem;resize:vertical;box-sizing:border-box" placeholder="Type your response here…"></textarea>
        <div style="display:flex;gap:8px;margin-top:6px;align-items:center">
          <button type="button" style="padding:5px 14px;background:#2563eb;border:1px solid #2563eb;color:#fff;font-size:0.75rem;cursor:pointer;font-family:inherit">Send reply</button>
          <span class="notif-reply-status" style="font-size:0.76rem;color:#166534;display:none"></span>
        </div>
      </div>` : ''}
    `;

    // Dismiss / Got it
    banner.querySelector('.notif-close').onclick = () => {
      banner.remove();
      sb.from('user_notifications')
        .update({ acknowledged_at: new Date().toISOString() })
        .eq('id', note.id)
        .then(() => {});
    };

    // Reply send
    if (isQuery) {
      const replyForm = banner.querySelector('#' + replyFormId);
      const replyBtn  = replyForm.querySelector('button');
      const replyArea = replyForm.querySelector('textarea');
      const replyStatus = replyForm.querySelector('.notif-reply-status');
      replyBtn.onclick = async () => {
        const msg = replyArea.value.trim();
        if (!msg) return;
        replyBtn.disabled = true;
        replyBtn.textContent = 'Sending…';
        const { error } = await sb.from('user_notifications')
          .update({
            reply_message:   msg,
            replied_at:      new Date().toISOString(),
            acknowledged_at: new Date().toISOString()
          })
          .eq('id', note.id);
        if (error) {
          replyBtn.disabled = false;
          replyBtn.textContent = 'Send reply';
          replyStatus.textContent = 'Could not send — try again.';
          replyStatus.style.color = '#c0392b';
          replyStatus.style.display = 'inline';
        } else {
          replyForm.innerHTML = '<div style="font-size:0.82rem;color:#166534;padding:4px 0">✔ Reply sent — the admin will see it in your correction.</div>';
        }
      };
    }

    const app = document.getElementById('app') || document.body;
    const claimBanner = document.getElementById('profile-claim-reminder');
    const ref = claimBanner?.nextSibling || app.querySelector('header')?.nextSibling;
    if (ref) app.insertBefore(banner, ref);
    else app.prepend(banner);
  }

  function removeProfileClaimBanner() {
    document.getElementById('profile-claim-reminder')?.remove();
  }

  function profileClaimDeadline(visitor, days) {
    // Prefer claim_clock_started_at (first successful login post-approval).
    // Falls back to the old signup-time basis for visitors who haven't
    // logged in again since this column was introduced.
    const basis = visitor?.claim_clock_started_at || visitor?.visitor_form_completed_at || visitor?.created_at || visitor?.first_seen || visitor?.updated_at || visitor?.last_seen;
    const time = new Date(basis || 0).getTime();
    return time ? new Date(time + days * 24 * 60 * 60 * 1000) : null;
  }

  function formatClaimDeadline(date) {
    if (!date) return '';
    return date.toLocaleString('en-IN', {
      timeZone: 'Asia/Kolkata',
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  async function hasProfileClaim(visitor) {
    const email = userEmail(currentSession?.user) || visitor?.email || '';
    const mobile = visitor?.mobile || sessionStorage.getItem('akt_visitor_mobile') || '';
    const authId = currentSession?.user?.id || visitor?.auth_user_id || sessionStorage.getItem('akt_auth_user_id') || '';
    const clauses = [];
    if (authId) clauses.push(`auth_user_id.eq.${authId}`);
    if (email) clauses.push(`claimant_email.eq.${email}`);
    if (mobile) clauses.push(`claimant_mobile.eq.${mobile}`);
    if (!clauses.length) return false;
    const { data, error } = await sb.from('profile_claims')
      .select('id')
      .or(clauses.join(','))
      .limit(1);
    if (error) {
      if (!/does not exist|schema cache|relation/i.test(error.message || '')) {
        console.warn('Profile claim reminder lookup failed:', error.message);
      }
      return false;
    }
    return Boolean(data && data.length);
  }

  function ensureProfileClaimBannerStyles() {
    if (document.getElementById('profile-claim-reminder-styles')) return;
    const style = document.createElement('style');
    style.id = 'profile-claim-reminder-styles';
    style.textContent = `
      #profile-claim-reminder {
        background: #fff7e8;
        border: 1px solid rgba(201,168,76,0.55);
        border-left: 4px solid #c9a84c;
        color: #4f4435;
        font-family: 'Lato', sans-serif;
        margin: 18px auto 0;
        max-width: min(1120px, calc(100% - 36px));
        padding: 14px 16px;
      }
      #profile-claim-reminder strong { color: #2e6e4a; }
      #profile-claim-reminder .claim-reminder-title {
        font-size: 0.88rem;
        font-weight: 700;
        margin-bottom: 5px;
      }
      #profile-claim-reminder .claim-reminder-copy {
        font-size: 0.8rem;
        line-height: 1.55;
      }
      #profile-claim-reminder .claim-reminder-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin-top: 10px;
      }
      #profile-claim-reminder a,
      #profile-claim-reminder button {
        background: #2e6e4a;
        border: 1px solid #2e6e4a;
        color: #fff;
        cursor: pointer;
        font-family: 'Lato', sans-serif;
        font-size: 0.72rem;
        font-weight: 700;
        letter-spacing: 0.06em;
        padding: 7px 11px;
        text-decoration: none;
        text-transform: uppercase;
      }
      #profile-claim-reminder button {
        background: transparent;
        color: #7a6e5e;
        border-color: rgba(122,110,94,0.35);
      }
    `;
    document.head.appendChild(style);
  }

  function renderProfileClaimBanner(visitor) {
    ensureProfileClaimBannerStyles();
    removeProfileClaimBanner();
    const claimBy = profileClaimDeadline(visitor, 3);
    const addBy = profileClaimDeadline(visitor, 7);
    const banner = document.createElement('div');
    banner.id = 'profile-claim-reminder';
    banner.innerHTML = `
      <div class="claim-reminder-title">Please claim your family profile</div>
      <div class="claim-reminder-copy">
        If your profile already exists, claim it within <strong>72 hours</strong>${claimBy ? `, by <strong>${formatClaimDeadline(claimBy)} IST</strong>` : ''}, before access may be blocked.
        If your profile is missing, raise a correction/request to get yourself added and claim it within <strong>one week</strong>${addBy ? `, by <strong>${formatClaimDeadline(addBy)} IST</strong>` : ''} from your first login.
      </div>
      <div class="claim-reminder-actions">
        <a href="index.html">Find my profile</a>
        <a href="index.html#corrections">Raise correction</a>
        <button type="button" onclick="document.getElementById('profile-claim-reminder')?.remove()">Dismiss</button>
      </div>
    `;
    const app = document.getElementById('app') || document.body;
    const header = app.querySelector('header');
    if (header?.nextSibling) {
      app.insertBefore(banner, header.nextSibling);
    } else {
      app.prepend(banner);
    }
  }

  async function refreshProfileClaimBanner(visitor = currentVisitor) {
    if (!visitor || !isOnboardingComplete(visitor)) {
      removeProfileClaimBanner();
      return;
    }
    if (await hasProfileClaim(visitor)) {
      removeProfileClaimBanner();
      return;
    }
    renderProfileClaimBanner(visitor);
  }

  function ensureRoleApplicationStyles() {
    if (document.getElementById('role-application-styles')) return;
    const style = document.createElement('style');
    style.id = 'role-application-styles';
    style.textContent = `
      #role-application-callout {
        background: #f7fbf6;
        border: 1px solid rgba(46,110,74,0.28);
        border-left: 4px solid #2e6e4a;
        color: #4f4435;
        font-family: 'Lato', sans-serif;
        margin: 12px auto 0;
        max-width: min(1120px, calc(100% - 36px));
        padding: 14px 16px;
      }
      #role-application-callout .role-app-title { color: #2e6e4a; font-size: 0.88rem; font-weight: 700; margin-bottom: 5px; }
      #role-application-callout .role-app-copy { font-size: 0.8rem; line-height: 1.55; }
      #role-application-callout .role-app-actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px; }
      #role-application-callout button,
      .role-app-modal button {
        background: #2e6e4a;
        border: 1px solid #2e6e4a;
        color: #fff;
        cursor: pointer;
        font-family: 'Lato', sans-serif;
        font-size: 0.72rem;
        font-weight: 700;
        letter-spacing: 0.06em;
        padding: 7px 11px;
        text-transform: uppercase;
      }
      #role-application-callout button.secondary,
      .role-app-modal button.secondary { background: transparent; color: #7a6e5e; border-color: rgba(122,110,94,0.35); }
      .role-app-modal-backdrop {
        align-items: center;
        background: rgba(42,35,24,0.48);
        display: flex;
        inset: 0;
        justify-content: center;
        padding: 24px;
        position: fixed;
        z-index: 9999;
      }
      .role-app-modal {
        background: #fffaf3;
        border: 1px solid rgba(201,168,76,0.45);
        box-shadow: 0 24px 80px rgba(42,35,24,0.25);
        color: #2a2318;
        max-width: 680px;
        padding: 22px;
        width: min(680px, 100%);
      }
      .role-app-modal h2 { color: #2e6e4a; font-size: 1.2rem; margin-bottom: 8px; }
      .role-app-modal p, .role-app-modal li { color: #5f5547; font-size: 0.84rem; line-height: 1.55; }
      .role-app-modal ul { margin: 12px 0 14px 18px; }
      .role-app-modal label { color: #6f5935; display: block; font-size: 0.72rem; font-weight: 700; letter-spacing: 0.08em; margin: 12px 0 6px; text-transform: uppercase; }
      .role-app-modal input,
      .role-app-modal select,
      .role-app-modal textarea {
        background: #fff;
        border: 1px solid #d9cdbb;
        color: #2a2318;
        font-family: 'Lato', sans-serif;
        font-size: 0.9rem;
        outline: none;
        padding: 10px 11px;
        width: 100%;
      }
      .role-app-modal textarea { min-height: 112px; resize: vertical; }
      .role-app-modal .role-app-status { color: #7a6e5e; font-size: 0.78rem; margin-top: 10px; }
    `;
    document.head.appendChild(style);
  }

  function removeRoleApplicationCallout() {
    document.getElementById('role-application-callout')?.remove();
  }

  function renderRoleApplicationCallout(visitor) {
    if (!visitor || normalizeAccessRole(visitor.access_role) === 'superadmin') {
      removeRoleApplicationCallout();
      return;
    }
    ensureRoleApplicationStyles();
    removeRoleApplicationCallout();
    const callout = document.createElement('div');
    callout.id = 'role-application-callout';
    callout.innerHTML = `
      <div class="role-app-title">Interested in helping as a moderator or admin?</div>
      <div class="role-app-copy">
        These roles are for people with good community knowledge, enthusiasm to broaden that knowledge, and a serious interest in community work.
        Moderators focus on profile-detail corrections. Admins have broader operational responsibilities.
        Requests are carefully chosen after due diligence, and site owners reserve the right to approve or disapprove any request.
        Anyone not logging in for one continuous month may be barred from the role.
      </div>
      <div class="role-app-actions">
        <button type="button" onclick="window.AKT_AUTH?.openRoleApplicationModal?.()">Apply for role</button>
        <button class="secondary" type="button" onclick="document.getElementById('role-application-callout')?.remove()">Dismiss</button>
      </div>
    `;
    const app = document.getElementById('app') || document.body;
    const claimBanner = document.getElementById('profile-claim-reminder');
    if (claimBanner?.nextSibling) {
      app.insertBefore(callout, claimBanner.nextSibling);
    } else {
      const header = app.querySelector('header');
      if (header?.nextSibling) app.insertBefore(callout, header.nextSibling);
      else app.prepend(callout);
    }
  }

  async function openRoleApplicationModal() {
    ensureRoleApplicationStyles();
    document.getElementById('role-application-modal')?.remove();
    const modal = document.createElement('div');
    modal.id = 'role-application-modal';
    modal.className = 'role-app-modal-backdrop';
    modal.innerHTML = `
      <div class="role-app-modal" role="dialog" aria-modal="true" aria-labelledby="role-app-title">
        <h2 id="role-app-title">Apply for moderator or admin role</h2>
        <p>Apply only if you have good knowledge of the family/community context, want to broaden that knowledge, and can contribute consistently.</p>
        <ul>
          <li><strong>Moderator:</strong> reviews corrections, duplicate flags, suggestions, and profile-detail edits such as names, dates, places, email, and mobile number.</li>
          <li><strong>Admin:</strong> helps manage users, GEDCOM operations, applied claims, reviews, and higher-trust operational work.</li>
          <li>Selections happen after due diligence. Site owners reserve full rights to approve or disapprove requests.</li>
          <li>Moderators/admins who do not log in for one continuous month may be removed from their role.</li>
        </ul>
        <label for="role-app-role">Role requested</label>
        <select id="role-app-role">
          <option value="moderator">Moderator</option>
          <option value="admin">Admin</option>
        </select>
        <label for="role-app-mobile">Mobile number for follow-up</label>
        <input id="role-app-mobile" type="tel" placeholder="Mobile number"/>
        <label for="role-app-profile-link">Your profile link in the shajra</label>
        <input id="role-app-profile-link" placeholder="Paste your profile link from Apno Ki Talash"/>
        <label for="role-app-note">Why should we consider you?</label>
        <textarea id="role-app-note" placeholder="Share your community knowledge, availability, and how you can help responsibly."></textarea>
        <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:14px">
          <button type="button" onclick="window.AKT_AUTH?.submitRoleApplication?.()">Submit request</button>
          <button class="secondary" type="button" onclick="window.AKT_AUTH?.closeRoleApplicationModal?.()">Cancel</button>
        </div>
        <div class="role-app-status" id="role-app-status"></div>
      </div>
    `;
    document.body.appendChild(modal);
    const visitor = currentVisitor || {};
    if (byId('role-app-mobile')) byId('role-app-mobile').value = visitor.mobile || sessionStorage.getItem('akt_visitor_mobile') || '';
    document.getElementById('role-app-note')?.focus();
  }

  function closeRoleApplicationModal() {
    document.getElementById('role-application-modal')?.remove();
  }

  function setRoleApplicationStatus(message, isError = false) {
    const el = document.getElementById('role-app-status');
    if (!el) return;
    el.textContent = message;
    el.style.color = isError ? '#8b2e2e' : '#2e6e4a';
  }

  async function submitRoleApplication() {
    const requestedRole = byId('role-app-role')?.value || 'moderator';
    const mobile = value('role-app-mobile');
    const profileLink = value('role-app-profile-link');
    const note = value('role-app-note');
    if (!['moderator', 'admin'].includes(requestedRole)) return setRoleApplicationStatus('Please select a valid role.', true);
    if (!mobile) return setRoleApplicationStatus('Please share your mobile number for follow-up.', true);
    if (!profileLink) return setRoleApplicationStatus('Please paste your existing shajra profile link.', true);
    if (note.length < 30) return setRoleApplicationStatus('Please share a little more context before submitting.', true);
    const visitor = currentVisitor || {};
    const payload = {
      visitor_id: visitor.id || null,
      auth_user_id: currentSession?.user?.id || visitor.auth_user_id || sessionStorage.getItem('akt_auth_user_id') || null,
      applicant_name: visitor.name_entered || sessionStorage.getItem('akt_visitor_name') || userName(currentSession?.user) || null,
      applicant_email: userEmail(currentSession?.user) || visitor.email || null,
      applicant_mobile: mobile,
      applicant_profile_link: profileLink,
      current_access_role: normalizeAccessRole(visitor.access_role || sessionStorage.getItem('akt_visitor_role')),
      requested_role: requestedRole,
      application_note: note,
      status: 'new',
      updated_at: new Date().toISOString()
    };
    setRoleApplicationStatus('Submitting request...');
    const { error } = await sb.from('role_applications').insert(payload);
    if (error) {
      if (/does not exist|schema cache|relation/i.test(error.message || '')) {
        return setRoleApplicationStatus('Role applications are not ready yet. Please ask admin to run supabase_role_applications.sql.', true);
      }
      return setRoleApplicationStatus(error.message, true);
    }
    setRoleApplicationStatus('Request submitted. Site owners will review it after due diligence.');
    setTimeout(closeRoleApplicationModal, 1400);
  }

  async function handleSession(session) {
    currentSession = session || null;
    if (!currentSession?.user) {
      currentVisitor = null;
      setView('signin');
      setNote('Sign in with Google or email. First-time visitors will complete a short consent form.');
      return;
    }

    setView('loading');
    await logSignupEvent('auth_success', { stage: 'signin' });
    const visitor = await findVisitorForUser(currentSession.user);
    currentVisitor = visitor;
    const status = visitorStatus(visitor);
    if (status === 'blocked' || status === 'rejected') {
      // Log blocked access attempt — use signup_events (open to all authenticated)
      await logSignupEvent('blocked_access_attempt', {
        stage: 'signin',
        status,
        email: userEmail(currentSession.user) || '',
        visitor_id: visitor?.id || null
      });
      setView('message');
      showBlockedMessage(status);
      return;
    }

    if (status === 'pending') {
      // Account exists but admin has not approved it yet — do not let them in.
      await logSignupEvent('pending_access_attempt', {
        stage: 'signin',
        status,
        email: userEmail(currentSession.user) || '',
        visitor_id: visitor?.id || null
      });
      setView('message');
      showPendingApprovalMessage();
      return;
    }

    if (visitor && isOnboardingComplete(visitor)) {
      if (await redirectForGuideIfNeeded(visitor)) return;
      await enterVisitor(visitor);
      await logSignupEvent('registered_user_entered', {
        stage: 'completed',
        visitor_id: visitor.id
      });
      return;
    }

    // Visitor is being routed back into onboarding — if that's because the
    // admin just revoked their (sole, genuine) profile claim, show a one-time
    // blocking explanation first so they understand why, before they redo
    // sign-up. They must press "OK, continue" to proceed.
    if (visitor) {
      const revokeNotice = await getClaimRevokeNotice(visitor);
      if (revokeNotice) {
        await logSignupEvent('claim_revoke_notice_shown', {
          stage: 'signin', visitor_id: visitor.id, notice_id: revokeNotice.id
        });
        setView('message');
        showClaimRevokedInterstitial(revokeNotice.message, async () => {
          sb.from('user_notifications')
            .update({ shown_at: new Date().toISOString(), acknowledged_at: new Date().toISOString() })
            .eq('id', revokeNotice.id)
            .then(() => {});
          fillOnboarding(currentSession.user, visitor);
          setView('onboarding');
          await logSignupEvent('onboarding_started', {
            stage: 'onboarding',
            step: currentOnboardingStep,
            form_snapshot: formSnapshot()
          });
          setNote('Complete this once. You will enter as a visitor by default; admins can block or update access later.');
        });
        return;
      }
    }

    fillOnboarding(currentSession.user, visitor);
    setView('onboarding');
    await logSignupEvent('onboarding_started', {
      stage: 'onboarding',
      step: currentOnboardingStep,
      form_snapshot: formSnapshot()
    });
    setNote('Complete this once. You will enter as a visitor by default; admins can block or update access later.');
  }

  async function signInWithGoogle() {
    if (!sb) return;
    await logSignupEvent('google_signin_started', { stage: 'signin' });
    setView('loading');
    const { error } = await sb.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: redirectTo() }
    });
    if (error) {
      await logSignupEvent('google_signin_failed', { stage: 'signin', error: error.message || '' });
      setView('signin');
      showMessage(error.message || 'Google sign-in failed.');
    }
  }

  async function sendMagicLink() {
    if (!sb) return;
    const email = value('auth-email').toLowerCase();
    if (!email || !email.includes('@')) {
      showMessage('Please enter a valid email address.');
      return;
    }
    const btn = byId('magic-link-btn');
    if (btn) {
      btn.disabled = true;
      btn.textContent = 'Sending...';
    }
    await logSignupEvent('magic_link_requested', { stage: 'signin', email });
    const { error } = await sb.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: redirectTo() }
    });
    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Send Magic Link';
    }
    if (error) {
      await logSignupEvent('magic_link_failed', { stage: 'signin', email, error: error.message || '' });
      showMessage(error.message || 'Could not send magic link.');
      return;
    }
    await logSignupEvent('magic_link_sent', { stage: 'signin', email });
    showMessage('Magic link sent. Please check your email and return through the link.', false);
  }

  function hideMessage() {
    const err = byId('auth-err');
    if (err) err.style.display = 'none';
  }

  function setOnboardingStep(step, shouldFocus = true) {
    currentOnboardingStep = Math.max(1, Math.min(3, Number(step) || 1));
    document.querySelectorAll('.onboarding-step').forEach(section => {
      section.hidden = Number(section.dataset.step || 0) !== currentOnboardingStep;
    });
    document.querySelectorAll('.reg-step').forEach((item, index) => {
      const itemStep = index + 1;
      item.classList.toggle('active', itemStep === currentOnboardingStep);
      item.classList.toggle('complete', itemStep < currentOnboardingStep);
    });
    const backBtn = byId('onboarding-back-btn');
    const nextBtn = byId('onboarding-next-btn');
    const submitBtn = byId('visitor-onboarding-submit');
    if (backBtn) backBtn.style.display = currentOnboardingStep > 1 ? 'inline-flex' : 'none';
    if (nextBtn) nextBtn.style.display = currentOnboardingStep < 3 ? 'inline-flex' : 'none';
    if (submitBtn) submitBtn.style.display = currentOnboardingStep === 3 ? 'inline-flex' : 'none';
    hideMessage();
    toggleHeardFromFields();
    if (shouldFocus) {
      document.querySelector('.auth-box')?.scrollIntoView({ block: 'start', behavior: 'smooth' });
      const firstField = document.querySelector(`.onboarding-step[data-step="${currentOnboardingStep}"] input:not([type="hidden"]), .onboarding-step[data-step="${currentOnboardingStep}"] select, .onboarding-step[data-step="${currentOnboardingStep}"] textarea`);
      setTimeout(() => firstField?.focus(), 120);
    }
  }

  function validateRequiredFields(required) {
    for (const [id, message] of required) {
      if (!value(id)) {
        showMessage(message);
        byId(id)?.focus();
        return false;
      }
    }
    return true;
  }

  function validateOnboardingStep(step = currentOnboardingStep) {
    if (step === 1) {
      return validateRequiredFields([
        ['visitor-name', 'Name is required.'],
        ['visitor-mobile', 'Mobile phone number is required.'],
        ['visitor-father-name', "Father's name is required."],
        ['visitor-root-place', 'Root place is required.'],
        ['visitor-current-place', 'Current place is required.']
      ]);
    }

    if (step === 2) {
      if (!validateRequiredFields([['visitor-heard-source', 'Please tell us where you heard about the website.']])) return false;
      if (value('visitor-heard-source') === 'relative' && (!value('visitor-heard-relative-name') || !value('visitor-heard-relative-place'))) {
        showMessage('Please add the relative name and place.');
        return false;
      }
      if (value('visitor-heard-source') === 'other' && !value('visitor-heard-details')) {
        showMessage('Please add where you heard about the website.');
        return false;
      }
      return true;
    }

    for (const section of REQUIRED_CONSENT_SECTIONS) {
      if (!checked('consent-section-' + section)) {
        showMessage('Please accept consent section ' + section + ' to continue.');
        return false;
      }
    }
    return true;
  }

  function validateOnboarding() {
    return validateOnboardingStep(1) && validateOnboardingStep(2) && validateOnboardingStep(3);
  }

  function nextOnboardingStep() {
    if (!validateOnboardingStep(currentOnboardingStep)) return;
    setOnboardingStep(currentOnboardingStep + 1);
    logSignupEvent('onboarding_step_changed', {
      stage: 'onboarding',
      step: currentOnboardingStep,
      direction: 'next',
      form_snapshot: formSnapshot()
    });
  }

  function prevOnboardingStep() {
    setOnboardingStep(currentOnboardingStep - 1);
    logSignupEvent('onboarding_step_changed', {
      stage: 'onboarding',
      step: currentOnboardingStep,
      direction: 'back',
      form_snapshot: formSnapshot()
    });
  }

  function formSnapshot() {
    return {
      name: value('visitor-name'),
      mobile: normalizeMobile(value('visitor-mobile')),
      father_name: value('visitor-father-name'),
      root_place: value('visitor-root-place'),
      current_place: value('visitor-current-place'),
      current_address: value('visitor-current-address'),
      oldest_ancestor: value('visitor-oldest-ancestor'),
      heard_from_source: value('visitor-heard-source'),
      heard_from_relative_name: value('visitor-heard-relative-name'),
      heard_from_relative_place: value('visitor-heard-relative-place'),
      heard_from_details: value('visitor-heard-details')
    };
  }

  async function submitOnboarding(event) {
    if (event) event.preventDefault();
    if (currentOnboardingStep < 3) {
      nextOnboardingStep();
      return;
    }
    if (!currentSession?.user) {
      showMessage('Please sign in first.');
      return;
    }
    if (!validateOnboarding()) return;

    const btn = byId('visitor-onboarding-submit');
    if (btn) {
      btn.disabled = true;
      btn.textContent = 'Saving...';
    }

    const snapshot = formSnapshot();
    await logSignupEvent('onboarding_submitted', {
      stage: 'onboarding',
      step: currentOnboardingStep,
      form_snapshot: snapshot
    });
    const now = new Date().toISOString();
    const payload = {
      auth_user_id: currentSession.user.id,
      email: userEmail(currentSession.user) || null,
      name_entered: snapshot.name,
      mobile: snapshot.mobile,
      family_reference: snapshot.root_place,
      father_name: snapshot.father_name,
      root_place: snapshot.root_place,
      current_place: snapshot.current_place,
      current_address: snapshot.current_address,
      oldest_ancestor: snapshot.oldest_ancestor,
      heard_from_source: snapshot.heard_from_source,
      heard_from_relative_name: snapshot.heard_from_relative_name || null,
      heard_from_relative_place: snapshot.heard_from_relative_place || null,
      heard_from_details: snapshot.heard_from_details || null,
      // New accounts start as 'pending' and require admin approval before they
      // can enter the archive (see handleSession's pending check + the
      // "pending approval" message below). Existing visitors keep whatever
      // status they already have — this only affects brand-new inserts.
      access_status: currentVisitor?.access_status || 'pending',
      access_role: currentVisitor?.access_role || 'visitor',
      is_blocked: currentVisitor?.is_blocked || false,
      visitor_form_completed: true,
      visitor_form_completed_at: now,
      consent_terms_accepted: true,
      consent_sections: REQUIRED_CONSENT_SECTIONS,
      consent_version: CONSENT_VERSION,
      consent_accepted_at: now,
      consent_ip_hint: getIpHint(),
      consent_user_agent: navigator.userAgent,
      last_seen: now,
      visit_count: Number(currentVisitor?.visit_count || 0),
      ip_hint: getIpHint(),
      updated_at: now
    };

    let saved = null;
    let error = null;
    if (currentVisitor?.id) {
      const result = await sb.from('visitors').update(payload).eq('id', currentVisitor.id).select('*').single();
      saved = result.data;
      error = result.error;
    } else {
      const result = await sb.from('visitors').insert(payload).select('*').single();
      saved = result.data;
      error = result.error;
    }

    if (error) {
      if (btn) {
        btn.disabled = false;
        btn.textContent = 'Accept & Enter';
      }
      await logSignupEvent('onboarding_submit_failed', {
        stage: 'onboarding',
        step: currentOnboardingStep,
        error: error.message || '',
        form_snapshot: snapshot
      });
      showMessage('Could not save visitor consent. Please run the latest access gate SQL and try again.');
      console.error(error);
      return;
    }

    await recordConsent(saved, snapshot);
    sessionStorage.removeItem(ONBOARDING_DRAFT_KEY);
    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Accept & Enter';
    }
    await logSignupEvent('onboarding_completed', {
      stage: 'completed',
      step: currentOnboardingStep,
      visitor_id: saved?.id || null,
      form_snapshot: snapshot
    });

    currentVisitor = saved;
    if (visitorStatus(saved) === 'pending') {
      // Brand-new (or still-unapproved) accounts do not enter the archive —
      // show the pending-approval message instead.
      await logSignupEvent('pending_after_onboarding', {
        stage: 'completed',
        visitor_id: saved?.id || null
      });
      setView('message');
      showPendingApprovalMessage();
      return;
    }

    if (await redirectForGuideIfNeeded(saved)) return;
    await enterVisitor(saved);
  }

  async function recordConsent(visitor, snapshot) {
    if (!visitor?.id) return;
    const { error } = await sb.from('visitor_consent_records').insert({
      visitor_id: visitor.id,
      auth_user_id: currentSession?.user?.id || null,
      email: userEmail(currentSession?.user) || null,
      consent_version: CONSENT_VERSION,
      accepted_sections: REQUIRED_CONSENT_SECTIONS,
      form_snapshot: snapshot,
      ip_hint: getIpHint(),
      user_agent: navigator.userAgent
    });
    if (error && !/does not exist|schema cache/i.test(error.message || '')) {
      console.warn('Consent audit insert failed', error.message);
    }
  }

  function toggleHeardFromFields() {
    const source = value('visitor-heard-source');
    const relative = byId('heard-relative-fields');
    const other = byId('heard-other-fields');
    if (relative) relative.style.display = source === 'relative' ? 'grid' : 'none';
    if (other) other.style.display = source === 'other' ? 'grid' : 'none';
  }

  async function signOut() {
    removeProfileClaimBanner();
    removeRoleApplicationCallout();
    closeRoleApplicationModal();
    sessionStorage.removeItem('akt_visitor_name');
    sessionStorage.removeItem('akt_visitor_mobile');
    sessionStorage.removeItem('akt_access_granted');
    sessionStorage.removeItem('akt_visitor_role');
    sessionStorage.removeItem('akt_auth_user_id');
    sessionStorage.removeItem(ONBOARDING_DRAFT_KEY);
    currentVisitor = null;
    currentSession = null;
    await sb?.auth.signOut();
    if (typeof callbacks.onSignOut === 'function') callbacks.onSignOut();
    setView('signin');
  }

  async function setup(options) {
    sb = options.sb;
    callbacks = options;
    if (initialized) return;
    initialized = true;

    setView('loading');
    bindDraftAutosave();
    logSignupEvent('login_page_viewed', { stage: 'signin' });
    const sessionResult = await sb.auth.getSession();
    await handleSession(sessionResult.data?.session || null);

    sb.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
        if (appLaunched) {
          // App already running — just update the session silently.
          // Do NOT re-initialise (causes reload / tree reset on tab focus).
          currentSession = session;
        } else {
          setTimeout(() => handleSession(session), 0);
        }
      }
      if (event === 'SIGNED_OUT') {
        appLaunched = false;
        setTimeout(() => handleSession(null), 0);
      }
    });
  }

  window.AKT_AUTH = {
    setup,
    signInWithGoogle,
    sendMagicLink,
    submitOnboarding,
    toggleHeardFromFields,
    nextOnboardingStep,
    prevOnboardingStep,
    setOnboardingStep,
    signOut,
    refreshProfileClaimBanner,
    openRoleApplicationModal,
    closeRoleApplicationModal,
    submitRoleApplication,
    normalizeAccessRole,
    CONSENT_VERSION
  };
})();
