(function () {
  const CONSENT_VERSION = 'terms-2026-05-25';
  const ONBOARDING_DRAFT_KEY = 'akt_onboarding_draft_v1';
  const REQUIRED_CONSENT_SECTIONS = ['6', '7', '8', '18'];
  const ROLE_LEVELS = { visitor: 1, moderator: 2, admin: 3, superadmin: 4 };

  let sb = null;
  let callbacks = {};
  let currentSession = null;
  let currentVisitor = null;
  let initialized = false;
  let currentOnboardingStep = 1;

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
    const email = userEmail(user);
    let found = null;
    let { data, error } = await sb.from('visitors')
      .select('*')
      .eq('auth_user_id', user.id)
      .order('last_seen', { ascending: false })
      .limit(1);
    if (!error && data && data.length) found = data[0];

    if (!found && email) {
      const emailResult = await sb.from('visitors')
        .select('*')
        .ilike('email', email)
        .order('last_seen', { ascending: false })
        .limit(1);
      if (!emailResult.error && emailResult.data && emailResult.data.length) found = emailResult.data[0];
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
    form.addEventListener('input', saveDraft);
    form.addEventListener('change', saveDraft);
  }

  async function enterVisitor(visitor) {
    currentVisitor = visitor;
    const role = normalizeAccessRole(visitor?.access_role);
    const name = visitor?.name_entered || userName(currentSession?.user) || 'Visitor';
    const mobile = visitor?.mobile || '';
    const visitCount = Number(visitor?.visit_count || 0) + 1;
    await sb.from('visitors').update({
      last_seen: new Date().toISOString(),
      visit_count: visitCount,
      auth_user_id: currentSession?.user?.id || visitor?.auth_user_id || null,
      email: userEmail(currentSession?.user) || visitor?.email || null,
      ip_hint: getIpHint(),
      updated_at: new Date().toISOString()
    }).eq('id', visitor.id);

    sessionStorage.setItem('akt_visitor_name', name);
    sessionStorage.setItem('akt_visitor_mobile', mobile);
    sessionStorage.setItem('akt_access_granted', '1');
    sessionStorage.setItem('akt_visitor_role', role);
    sessionStorage.setItem('akt_auth_user_id', currentSession?.user?.id || '');

    if (typeof callbacks.onStart === 'function') {
      await callbacks.onStart(name, role, { ...visitor, visit_count: visitCount });
    }
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
    const visitor = await findVisitorForUser(currentSession.user);
    currentVisitor = visitor;
    const status = visitorStatus(visitor);
    if (status === 'blocked' || status === 'rejected') {
      setView('message');
      showMessage('Your access is currently blocked or rejected. Please contact the administrator if this looks incorrect.', true);
      return;
    }

    if (visitor && isOnboardingComplete(visitor)) {
      await enterVisitor(visitor);
      return;
    }

    fillOnboarding(currentSession.user, visitor);
    setView('onboarding');
    setNote('Complete this once. You will enter as a visitor by default; admins can block or update access later.');
  }

  async function signInWithGoogle() {
    if (!sb) return;
    setView('loading');
    const { error } = await sb.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: redirectTo() }
    });
    if (error) {
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
    const { error } = await sb.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: redirectTo() }
    });
    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Send Magic Link';
    }
    if (error) {
      showMessage(error.message || 'Could not send magic link.');
      return;
    }
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
  }

  function prevOnboardingStep() {
    setOnboardingStep(currentOnboardingStep - 1);
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
      access_status: currentVisitor?.access_status || 'approved',
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
    const sessionResult = await sb.auth.getSession();
    await handleSession(sessionResult.data?.session || null);

    sb.auth.onAuthStateChange((event, session) => {
      if (['SIGNED_IN', 'TOKEN_REFRESHED'].includes(event)) {
        setTimeout(() => handleSession(session), 0);
      }
      if (event === 'SIGNED_OUT') {
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
    normalizeAccessRole,
    CONSENT_VERSION
  };
})();
