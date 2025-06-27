// Project Modal Functionality
document.addEventListener('DOMContentLoaded', function() {
    // Create modal HTML structure
    const modalHTML = `
        <div id="project-modal" class="modal-overlay">
            <div class="modal-content">
                <button class="modal-close" aria-label="Close modal">&times;</button>
                <div class="modal-header">
                    <img class="modal-image" src="" alt="" />
                    <div class="modal-info">
                        <h2 class="modal-title"></h2>
                        <p class="modal-description"></p>
                        <div class="modal-links"></div>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    // Add modal to page
    document.body.insertAdjacentHTML('beforeend', modalHTML);
    
    const modal = document.getElementById('project-modal');
    const modalContent = modal.querySelector('.modal-content');
    const closeBtn = modal.querySelector('.modal-close');
    const modalImage = modal.querySelector('.modal-image');
    const modalTitle = modal.querySelector('.modal-title');
    const modalDescription = modal.querySelector('.modal-description');
    const modalLinks = modal.querySelector('.modal-links');
    
    // Project data extracted from cards
    const projects = [];
    
    // Extract project data from existing cards
    function extractProjectData() {
        const cards = document.querySelectorAll('.card');
        cards.forEach((card, index) => {
            const image = card.querySelector('.card-image');
            const title = card.querySelector('.card-title');
            const description = card.querySelector('.card-description');
            
            if (image && title && description) {
                projects.push({
                    id: index,
                    image: image.src,
                    title: title.textContent.trim(),
                    description: description.textContent.trim(),
                    // Extract links from the original project pages if available
                    links: extractLinksFromCard(card)
                });
            }
        });
    }
    
    // Extract any existing links from the card or derive from project name
    function extractLinksFromCard(card) {
        const links = [];
        const titleText = card.querySelector('.card-title')?.textContent.trim().toLowerCase();
        
        // Add GitHub link based on project name patterns
        if (titleText) {
            if (titleText.includes('redzone')) {
                links.push({ text: 'View on GitHub', url: 'https://github.com/junebash/RedZone' });
                links.push({ text: 'App Store', url: 'https://apps.apple.com/us/app/redzone/id1492127706' });
            } else if (titleText.includes('rekor')) {
                links.push({ text: 'View on GitHub', url: 'https://github.com/junebash/rekor-go' });
            } else if (titleText.includes('eco-soap')) {
                links.push({ text: 'View on GitHub', url: 'https://github.com/junebash/Eco-Soap-Bank' });
            } else if (titleText.includes('countdown')) {
                links.push({ text: 'View on GitHub', url: 'https://github.com/junebash/super-countdown-tracker' });
                links.push({ text: 'App Store', url: 'https://apps.apple.com/us/app/super-countdown-tracker/id1484864299' });
            } else if (titleText.includes('game of life')) {
                links.push({ text: 'View on GitHub', url: 'https://github.com/junebash/GameOfLife' });
            } else if (titleText.includes('junebash.com')) {
                links.push({ text: 'View on GitHub', url: 'https://github.com/junebash/junebash_com_zola' });
                links.push({ text: 'Visit Site', url: 'https://junebash.com' });
            } else if (titleText.includes('snackify')) {
                links.push({ text: 'View on GitHub', url: 'https://github.com/junebash/Snackify' });
            } else if (titleText.includes('lambdi')) {
                links.push({ text: 'View on GitHub', url: 'https://github.com/junebash/lambdi-pet' });
            }
        }
        
        return links;
    }
    
    // Open modal with project data
    function openModal(projectIndex) {
        const project = projects[projectIndex];
        if (!project) return;
        
        modalImage.src = project.image;
        modalImage.alt = project.title;
        modalTitle.textContent = project.title;
        modalDescription.textContent = project.description;
        
        // Clear and populate links
        modalLinks.innerHTML = '';
        project.links.forEach(link => {
            const linkElement = document.createElement('a');
            linkElement.href = link.url;
            linkElement.className = 'modal-link';
            linkElement.textContent = link.text;
            linkElement.target = '_blank';
            linkElement.rel = 'noopener noreferrer';
            modalLinks.appendChild(linkElement);
        });
        
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
    
    // Close modal
    function closeModal() {
        modal.classList.remove('active');
        document.body.style.overflow = '';
    }
    
    // Event listeners
    closeBtn.addEventListener('click', closeModal);
    
    // Close on overlay click
    modal.addEventListener('click', function(e) {
        if (e.target === modal) {
            closeModal();
        }
    });
    
    // Close on escape key
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && modal.classList.contains('active')) {
            closeModal();
        }
    });
    
    // Prevent modal content clicks from closing modal
    modalContent.addEventListener('click', function(e) {
        e.stopPropagation();
    });
    
    // Initialize
    extractProjectData();
    
    // Add click listeners to cards
    const cards = document.querySelectorAll('.card');
    cards.forEach((card, index) => {
        card.addEventListener('click', function(e) {
            e.preventDefault();
            openModal(index);
        });
    });
});