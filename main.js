// 江西 AI 圈 — interactions

(function () {
  'use strict';
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ---------- Nav scroll state ----------
  const nav = document.getElementById('nav');
  const onScroll = () => {
    if (window.scrollY > 12) nav.classList.add('scrolled');
    else nav.classList.remove('scrolled');
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // ---------- Mobile nav toggle ----------
  const toggle = document.getElementById('navToggle');
  const links = document.querySelector('.nav-links');
  if (toggle && links) {
    const setNavOpen = (open) => {
      links.classList.toggle('show', open);
      toggle.setAttribute('aria-expanded', String(open));
      document.body.classList.toggle('nav-open', open);
    };
    toggle.addEventListener('click', () => setNavOpen(!links.classList.contains('show')));
    links.querySelectorAll('a').forEach(a =>
      a.addEventListener('click', () => setNavOpen(false))
    );
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && links.classList.contains('show')) {
        setNavOpen(false);
        toggle.focus();
      }
    });
  }

  // ---------- Nav dropdown (click to toggle on touch / mobile) ----------
  document.querySelectorAll('.nav-dropdown').forEach((dd) => {
    const trigger = dd.querySelector('.nav-drop-trigger');
    if (!trigger) return;
    trigger.addEventListener('click', (e) => {
      // On desktop, hover handles it; on touch / mobile, toggle open
      if (window.matchMedia('(max-width: 800px)').matches || e.detail > 0) {
        e.preventDefault();
        const isOpen = dd.classList.toggle('open');
        trigger.setAttribute('aria-expanded', String(isOpen));
      }
    });
  });
  // Close dropdown when clicking outside
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.nav-dropdown')) {
      document.querySelectorAll('.nav-dropdown.open').forEach((dd) => {
        dd.classList.remove('open');
        const t = dd.querySelector('.nav-drop-trigger');
        if (t) t.setAttribute('aria-expanded', 'false');
      });
    }
  });
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    document.querySelectorAll('.nav-dropdown.open').forEach((dd) => {
      dd.classList.remove('open');
      const trigger = dd.querySelector('.nav-drop-trigger');
      if (trigger) {
        trigger.setAttribute('aria-expanded', 'false');
        trigger.focus();
      }
    });
  });

  // ---------- Counter animation ----------
  const counters = document.querySelectorAll('.hero-stats strong[data-target]');
  const animateCounter = (el) => {
    const target = parseInt(el.dataset.target, 10);
    const suffix = el.dataset.suffix || '';
    if (prefersReducedMotion) {
      el.textContent = target + suffix;
      return;
    }
    const duration = 1600;
    const start = performance.now();
    const tick = (now) => {
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - t, 3);
      el.textContent = Math.floor(target * eased) + suffix;
      if (t < 1) requestAnimationFrame(tick);
      else el.textContent = target + suffix;
    };
    requestAnimationFrame(tick);
  };

  // ---------- Reveal on scroll ----------
  const revealEls = document.querySelectorAll(
    '.reveal, .section-head, .about-grid, .value-card, .brand-card, .night-cards, .night-illust, .solution, .logos-strip, .member, .partner-card, .city-banner, .cta-head, .cta-qr, .cta-form, .gallery-filters, .gallery-grid, .opc-space-card, .demand-card, .opc-stats-bar, .aidaily-banner'
  );
  revealEls.forEach(el => el.classList.add('reveal'));

  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

    revealEls.forEach(el => io.observe(el));

    // Counter trigger
    const heroStats = document.querySelector('.hero-stats');
    if (heroStats) {
      const cio = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            counters.forEach(animateCounter);
            cio.disconnect();
          }
        });
      }, { threshold: 0.3 });
      cio.observe(heroStats);
    }
  } else {
    revealEls.forEach(el => el.classList.add('visible'));
    counters.forEach(animateCounter);
  }

  // ---------- Smooth anchor offset for sticky nav ----------
  document.querySelectorAll('a[href^="#"]').forEach(a => {
    a.addEventListener('click', (e) => {
      const id = a.getAttribute('href');
      if (id.length < 2) return;
      const el = document.querySelector(id);
      if (!el) return;
      e.preventDefault();
      const top = el.getBoundingClientRect().top + window.scrollY - 60;
      window.scrollTo({ top, behavior: prefersReducedMotion ? 'auto' : 'smooth' });
    });
  });

  // ---------- AI 日报日期动态显示 ----------
  const aidailyDate = document.getElementById('aidailyDate');
  if (aidailyDate) {
    const now = new Date();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    aidailyDate.textContent = `${mm}月${dd}日`;
  }


  // ---------- Gallery filter & lightbox (only on pages with gallery) ----------
  const filters = document.querySelectorAll('.g-filter');
  const items = Array.from(document.querySelectorAll('.g-item'));
  const loadMoreBtn = document.getElementById('loadMoreBtn');
  const galleryLoadmore = document.getElementById('galleryLoadmore');
  const lb = document.getElementById('lightbox');
  const lbImg = document.getElementById('lbImg');
  const lbCap = document.getElementById('lbCap');

  if (items.length && galleryLoadmore && lb && lbImg && lbCap) {
    const PER_PAGE = 9;
    let page = 1;
    let activeCat = 'all';

    const applyFilter = (cat) => {
      activeCat = cat;
      page = 1;
      let matchIdx = 0;
      items.forEach((it) => {
        const isMatch = (cat === 'all' || it.dataset.cat === cat);
        if (isMatch) {
          it.classList.toggle('hidden', matchIdx >= PER_PAGE);
          matchIdx++;
        } else {
          it.classList.add('hidden');
        }
      });
      if (matchIdx <= PER_PAGE) {
        galleryLoadmore.style.display = 'none';
      } else {
        galleryLoadmore.style.display = 'flex';
      }
    };

    filters.forEach(f => {
      f.setAttribute('aria-pressed', String(f.classList.contains('active')));
      f.addEventListener('click', () => {
        filters.forEach(x => {
          const isActive = x === f;
          x.classList.toggle('active', isActive);
          x.setAttribute('aria-pressed', String(isActive));
        });
        applyFilter(f.dataset.filter);
      });
    });

    // Initially apply filter
    applyFilter('all');

    // Load more
    if (loadMoreBtn) {
      loadMoreBtn.addEventListener('click', () => {
        page++;
        const showCount = page * PER_PAGE;
        let matchIdx = 0;
        items.forEach((it) => {
          const isMatch = (activeCat === 'all' || it.dataset.cat === activeCat);
          if (isMatch) {
            it.classList.toggle('hidden', matchIdx >= showCount);
            matchIdx++;
          } else {
            it.classList.add('hidden');
          }
        });
        if (matchIdx <= showCount) {
          galleryLoadmore.style.display = 'none';
        }
      });
    }

    // ---------- Lightbox ----------
    let lbIdx = 0;
    let previousFocus = null;
    let visibleItems = () => items.filter(it => !it.classList.contains('hidden'));

    const openLb = (idx, origin = null) => {
      const list = visibleItems();
      if (!list.length) return;
      const wasOpen = lb.classList.contains('open');
      lbIdx = ((idx % list.length) + list.length) % list.length;
      const target = list[lbIdx];
      const img = target.querySelector('img');
      const cap = target.querySelector('figcaption');
      lbImg.src = img.currentSrc || img.src;
      lbImg.alt = img.alt;
      lbCap.textContent = cap ? cap.textContent.trim() : '';
      lb.classList.add('open');
      lb.setAttribute('aria-hidden', 'false');
      document.body.style.overflow = 'hidden';
      if (!wasOpen) {
        previousFocus = origin || document.activeElement;
        lb.querySelector('.lb-close').focus();
      }
    };
    const closeLb = () => {
      if (!lb.classList.contains('open')) return;
      lb.classList.remove('open');
      lb.setAttribute('aria-hidden', 'true');
      document.body.style.overflow = '';
      if (previousFocus && previousFocus.isConnected) previousFocus.focus();
      previousFocus = null;
    };
    const stepLb = (delta) => openLb(lbIdx + delta);

    items.forEach((it) => {
      const itemImg = it.querySelector('img');
      it.setAttribute('tabindex', '0');
      it.setAttribute('role', 'button');
      it.setAttribute('aria-label', `查看大图：${itemImg?.alt || '活动照片'}`);
      it.addEventListener('click', () => {
        const list = visibleItems();
        const idx = list.indexOf(it);
        if (idx >= 0) openLb(idx, it);
      });
      it.addEventListener('keydown', (e) => {
        if (e.key !== 'Enter' && e.key !== ' ') return;
        e.preventDefault();
        const list = visibleItems();
        const idx = list.indexOf(it);
        if (idx >= 0) openLb(idx, it);
      });
    });

    lb.querySelector('.lb-close').addEventListener('click', closeLb);
    lb.querySelector('.lb-prev').addEventListener('click', () => stepLb(-1));
    lb.querySelector('.lb-next').addEventListener('click', () => stepLb(1));
    lb.addEventListener('click', (e) => { if (e.target === lb) closeLb(); });
    document.addEventListener('keydown', (e) => {
      if (!lb.classList.contains('open')) return;
      if (e.key === 'Escape') closeLb();
      else if (e.key === 'ArrowLeft') stepLb(-1);
      else if (e.key === 'ArrowRight') stepLb(1);
    });
  }

  // ---------- News list render (only on news page) ----------
  const newsTimeline = document.getElementById('newsTimeline');
  if (newsTimeline) {
    const newsEmpty = document.getElementById('newsEmpty');
    const newsTypeTabs = document.querySelectorAll('.news-type-tab');
    const newsTotalCount = document.getElementById('newsTotalCount');
    const newsMediaCount = document.getElementById('newsMediaCount');
    const newsWechatCount = document.getElementById('newsWechatCount');
    let newsActiveType = 'all';

    const badgeLabels = {
      media: '外界见闻',
      wechat: '实战笔记',
      event: '交流预告',
      voice: '思考发声'
    };

    const formatDate = (dateStr) => {
      const d = new Date(dateStr);
      const yyyy = d.getFullYear();
      const mm = String(d.getMonth() + 1).padStart(2, '0');
      const dd = String(d.getDate()).padStart(2, '0');
      return yyyy + '.' + mm + '.' + dd;
    };

    const renderNews = (data) => {
      newsTimeline.innerHTML = '';
      if (!data.length) {
        newsEmpty.style.display = 'block';
        return;
      }
      newsEmpty.style.display = 'none';

      data.forEach((item) => {
        const article = document.createElement('article');
        article.className = 'news-item reveal' + (item.featured ? ' featured' : '');
        article.dataset.type = item.sourceType;
        article.dataset.category = item.category;
        article.dataset.newsId = item.id;

        const badgeClass = 'news-badge-' + item.sourceType;
        const badgeLabel = badgeLabels[item.sourceType] || item.sourceType;

        article.innerHTML =
          '<div class="news-dot" aria-hidden="true"></div>' +
          '<a class="news-card" href="' + item.url + '" target="_blank" rel="noopener">' +
            '<div class="news-card-head">' +
              '<time class="news-date" datetime="' + item.date + '">' + formatDate(item.date) + '</time>' +
              '<span class="news-badge ' + badgeClass + '">' + badgeLabel + '</span>' +
              '<span class="news-source">' + item.source + '</span>' +
              (item.featured ? '<span class="news-featured-tag">推荐</span>' : '') +
            '</div>' +
            '<h3 class="news-title">' + item.title + '</h3>' +
            (item.summary ? '<p class="news-summary">' + item.summary + '</p>' : '') +
            '<span class="news-link">阅读原文</span>' +
          '</a>';

        newsTimeline.appendChild(article);
      });

      // Reveal animation
      if ('IntersectionObserver' in window) {
        const io = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              entry.target.classList.add('visible');
              io.unobserve(entry.target);
            }
          });
        }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
        newsTimeline.querySelectorAll('.news-item').forEach(el => io.observe(el));
      } else {
        newsTimeline.querySelectorAll('.news-item').forEach(el => el.classList.add('visible'));
      }
    };

    const filterNewsItems = () => {
      let visibleCount = 0;
      newsTimeline.querySelectorAll('.news-item').forEach(el => {
        const matchesType = (newsActiveType === 'all' || el.dataset.type === newsActiveType);
        el.style.display = matchesType ? '' : 'none';
        if (matchesType) visibleCount++;
      });
      if (newsEmpty) {
        newsEmpty.style.display = visibleCount === 0 ? 'block' : 'none';
      }
    };

    newsTypeTabs.forEach(tab => {
      tab.addEventListener('click', () => {
        newsActiveType = tab.dataset.typeFilter;
        newsTypeTabs.forEach(t => {
          const isActive = t === tab;
          t.classList.toggle('active', isActive);
          t.setAttribute('aria-selected', String(isActive));
        });
        filterNewsItems();
      });
    });

    // Animate statically rendered items
    if ('IntersectionObserver' in window) {
      const io = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            io.unobserve(entry.target);
          }
        });
      }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
      newsTimeline.querySelectorAll('.news-item').forEach(el => io.observe(el));
    } else {
      newsTimeline.querySelectorAll('.news-item').forEach(el => el.classList.add('visible'));
    }
  }

  // ---------- Friendly links ----------
  // Keep the same verified partner links on every page without duplicating
  // the footer markup across all static documents.
  const footerContainer = document.querySelector('.footer > .container');
  const footerDisclaimer = footerContainer && footerContainer.querySelector('.footer-disclaimer');
  const footerBottom = footerContainer && footerContainer.querySelector('.footer-bottom');
  const insertTarget = footerDisclaimer || footerBottom;
  if (footerContainer && insertTarget && !footerContainer.querySelector('.friend-links')) {
    const friendLinks = document.createElement('nav');
    friendLinks.className = 'friend-links';
    friendLinks.setAttribute('aria-label', '友情链接');
    friendLinks.innerHTML =
      '<strong>友情链接</strong>' +
      '<div class="friend-links-list">' +
        '<a href="https://www.minimaxi.com/" target="_blank" rel="noopener">稀宇 MiniMax</a>' +
        '<a href="https://www.miaoda.cn/" target="_blank" rel="noopener">百度秒哒</a>' +
        '<a href="https://www.waytoagi.com/" target="_blank" rel="noopener">WaytoAGI</a>' +
        '<a href="https://www.opc.city/" target="_blank" rel="noopener">OPCxCity</a>' +
      '</div>';
    footerContainer.insertBefore(friendLinks, insertTarget);
  }

  // ---------- Conversion signals ----------
  const sendAnalyticsEvent = (name, params) => {
    if (typeof window.gtag === 'function') window.gtag('event', name, params);
  };

  document.querySelectorAll('a').forEach((link) => {
    const href = link.getAttribute('href') || '';
    const isPrimaryAction = link.matches('.btn, .nav-cta, .float-cta, .cta-path, .value-cta, .source-link');
    const isForm = href.includes('feishu.cn/share/base/form');
    if (!isPrimaryAction && !isForm) return;
    link.addEventListener('click', () => {
      sendAnalyticsEvent('cta_click', {
        cta_text: (link.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 80),
        cta_target: href.split('?')[0],
        page_path: window.location.pathname
      });
    });
  });
})();
