// Enhanced Code Project Modal with Rich Content Support
document.addEventListener('DOMContentLoaded', function() {
    // Create enhanced modal HTML structure
    const modalHTML = `
        <div id="code-modal" class="modal-overlay">
            <div class="modal-content code-modal-content">
                <button class="modal-close" aria-label="Close modal">&times;</button>
                <div class="code-modal-header">
                    <div class="code-icon-container">
                        <img class="code-icon" src="" alt="" />
                    </div>
                    <div class="code-info">
                        <h2 class="code-title"></h2>
                        <p class="code-description"></p>
                        <div class="code-links"></div>
                    </div>
                </div>
                <div class="code-content">
                    <div class="code-screenshots"></div>
                    <div class="code-features"></div>
                    <div class="code-planned-features"></div>
                    <div class="code-full-description"></div>
                </div>
            </div>
        </div>
    `;
    
    // Add modal to page
    document.body.insertAdjacentHTML('beforeend', modalHTML);
    
    const modal = document.getElementById('code-modal');
    const modalContent = modal.querySelector('.modal-content');
    const closeBtn = modal.querySelector('.modal-close');
    
    // Code project data
    const codeProjects = [];
    
    // Extract code project data from data attributes
    function extractCodeProjectData() {
        const cards = document.querySelectorAll('.music-item[data-code-title]');
        cards.forEach((card, index) => {
            const screenshots = card.getAttribute('data-code-screenshots');
            const features = card.getAttribute('data-code-features');
            const plannedFeatures = card.getAttribute('data-code-planned-features');
            
            codeProjects[index] = {
                title: card.getAttribute('data-code-title') || '',
                description: card.getAttribute('data-code-description') || '',
                content: card.getAttribute('data-code-content') || '',
                extra: {
                    icon: card.getAttribute('data-code-icon') || null,
                    ios_store: card.getAttribute('data-code-ios-store') || null,
                    source: card.getAttribute('data-code-source') || null,
                    screenshots: screenshots ? screenshots.split(',') : null,
                    features: features ? features.split('|') : null,
                    planned_features: plannedFeatures ? plannedFeatures.split('|') : null
                }
            };
            
            // Debug logging
            console.log('Code Project', index, ':', codeProjects[index]);
        });
    }
    
    // Create screenshot carousel
    function createScreenshotCarousel(screenshots) {
        if (!screenshots || screenshots.length === 0) return '';
        
        const carouselId = 'code-carousel';
        let carouselHTML = `
            <div class="code-section">
                <h3>Screenshots</h3>
                <div id="${carouselId}" class="screenshot-carousel">
                    <div class="carousel-track">
        `;
        
        screenshots.forEach((screenshot, index) => {
            carouselHTML += `
                <div class="carousel-slide ${index === 0 ? 'active' : ''}">
                    <img src="/${screenshot}" alt="Screenshot ${index + 1}" class="screenshot-image" />
                </div>
            `;
        });
        
        carouselHTML += `
                    </div>
                    <div class="carousel-controls">
                        <button class="carousel-btn prev-btn" aria-label="Previous screenshot">&lt;</button>
                        <button class="carousel-btn next-btn" aria-label="Next screenshot">&gt;</button>
                    </div>
                    <div class="carousel-indicators">
        `;
        
        screenshots.forEach((_, index) => {
            carouselHTML += `<span class="indicator ${index === 0 ? 'active' : ''}" data-slide="${index}"></span>`;
        });
        
        carouselHTML += `
                    </div>
                </div>
            </div>
        `;
        
        return carouselHTML;
    }
    
    // Create features list
    function createFeaturesList(features, title) {
        if (!features || features.length === 0) return '';
        
        let html = `
            <div class="code-section">
                <h3>${title}</h3>
                <ul class="features-list">
        `;
        
        features.forEach(feature => {
            html += `<li>${feature}</li>`;
        });
        
        html += `
                </ul>
            </div>
        `;
        
        return html;
    }
    
    // Create App Store button
    function createAppStoreButton(url) {
        if (!url) return '';
        
        return `
            <a href="${url}" target="_blank" rel="noopener noreferrer" class="app-store-button">
                <img src="/images/appstoredownload.svg" alt="Download on the App Store" class="app-store-image" />
            </a>
        `;
    }
    
    // Open modal with enhanced code project data
    function openModal(codeProjectIndex) {
        const codeProject = codeProjects[codeProjectIndex];
        if (!codeProject) return;
        
        const modalIcon = modal.querySelector('.code-icon');
        const modalTitle = modal.querySelector('.code-title');
        const modalDescription = modal.querySelector('.code-description');
        const modalLinks = modal.querySelector('.code-links');
        const screenshotsContainer = modal.querySelector('.code-screenshots');
        const featuresContainer = modal.querySelector('.code-features');
        const plannedFeaturesContainer = modal.querySelector('.code-planned-features');
        const fullDescriptionContainer = modal.querySelector('.code-full-description');
        
        // Set basic info
        if (codeProject.extra && codeProject.extra.icon) {
            modalIcon.src = '/' + codeProject.extra.icon;
            modalIcon.alt = codeProject.title + ' icon';
            modalIcon.style.display = 'block';
        } else {
            modalIcon.style.display = 'none';
        }
        
        modalTitle.textContent = codeProject.title;
        modalDescription.textContent = codeProject.description || '';
        
        // Create links
        modalLinks.innerHTML = '';
        if (codeProject.extra) {
            if (codeProject.extra.ios_store) {
                modalLinks.innerHTML += createAppStoreButton(codeProject.extra.ios_store);
            }
            if (codeProject.extra.source) {
                const githubLink = document.createElement('a');
                githubLink.href = codeProject.extra.source;
                githubLink.className = 'modal-link github-link';
                githubLink.textContent = 'View on GitHub';
                githubLink.target = '_blank';
                githubLink.rel = 'noopener noreferrer';
                modalLinks.appendChild(githubLink);
            }
        }
        
        // Add screenshots carousel
        if (codeProject.extra && codeProject.extra.screenshots) {
            screenshotsContainer.innerHTML = createScreenshotCarousel(codeProject.extra.screenshots);
            setupCarouselControls();
        } else {
            screenshotsContainer.innerHTML = '';
        }
        
        // Add features
        if (codeProject.extra && codeProject.extra.features) {
            featuresContainer.innerHTML = createFeaturesList(codeProject.extra.features, 'Features');
        } else {
            featuresContainer.innerHTML = '';
        }
        
        // Add planned features
        if (codeProject.extra && codeProject.extra.planned_features) {
            plannedFeaturesContainer.innerHTML = createFeaturesList(codeProject.extra.planned_features, 'Planned Features');
        } else {
            plannedFeaturesContainer.innerHTML = '';
        }
        
        // Add full description
        if (codeProject.content) {
            // Decode HTML entities and create a proper HTML element
            const tempDiv = document.createElement('div');
            tempDiv.innerHTML = codeProject.content;
            const decodedContent = tempDiv.innerHTML;
            
            fullDescriptionContainer.innerHTML = `
                <div class="code-section">
                    <div class="code-content-text">${decodedContent}</div>
                </div>
            `;
        } else {
            fullDescriptionContainer.innerHTML = '';
        }
        
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
    
    // Setup carousel controls
    function setupCarouselControls() {
        const carousel = modal.querySelector('.screenshot-carousel');
        if (!carousel) return;
        
        const slides = carousel.querySelectorAll('.carousel-slide');
        const indicators = carousel.querySelectorAll('.indicator');
        const prevBtn = carousel.querySelector('.prev-btn');
        const nextBtn = carousel.querySelector('.next-btn');
        
        let currentSlide = 0;
        
        function showSlide(index) {
            slides.forEach((slide, i) => {
                slide.classList.toggle('active', i === index);
            });
            indicators.forEach((indicator, i) => {
                indicator.classList.toggle('active', i === index);
            });
            currentSlide = index;
        }
        
        prevBtn.addEventListener('click', () => {
            const newIndex = currentSlide > 0 ? currentSlide - 1 : slides.length - 1;
            showSlide(newIndex);
        });
        
        nextBtn.addEventListener('click', () => {
            const newIndex = currentSlide < slides.length - 1 ? currentSlide + 1 : 0;
            showSlide(newIndex);
        });
        
        indicators.forEach((indicator, index) => {
            indicator.addEventListener('click', () => showSlide(index));
        });
    }
    
    // Close modal
    function closeModal() {
        modal.classList.remove('active');
        document.body.style.overflow = '';
    }
    
    // Event listeners
    closeBtn.addEventListener('click', closeModal);
    
    modal.addEventListener('click', function(e) {
        if (e.target === modal) {
            closeModal();
        }
    });
    
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && modal.classList.contains('active')) {
            closeModal();
        }
    });
    
    modalContent.addEventListener('click', function(e) {
        e.stopPropagation();
    });
    
    // Initialize
    extractCodeProjectData();
    
    // Add click listeners to cards
    const cards = document.querySelectorAll('.music-item');
    cards.forEach((card, index) => {
        card.addEventListener('click', function(e) {
            e.preventDefault();
            openModal(index);
        });
    });
});