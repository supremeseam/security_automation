document.addEventListener('DOMContentLoaded', function () {
    const loginButton = document.getElementById('login-btn');
    const logoutButton = document.getElementById('logout-btn');
    const contentDiv = document.getElementById('content');

    const idToken = localStorage.getItem('id_token');

    if (idToken) {
        // User is logged in
        loginButton.style.display = 'none';
        logoutButton.style.display = 'block';
        contentDiv.style.display = 'block';
        fetchAutomations();
    } else {
        // User is not logged in
        loginButton.style.display = 'block';
        logoutButton.style.display = 'none';
        contentDiv.style.display = 'none';
    }

    loginButton.addEventListener('click', () => {
        window.location.href = '/login';
    });

    logoutButton.addEventListener('click', () => {
        localStorage.removeItem('id_token');
        localStorage.removeItem('access_token');
        window.location.href = '/logout';
    });
});

async function fetchAutomations() {
    const idToken = localStorage.getItem('id_token');
    if (!idToken) {
        return;
    }

    try {
        const response = await fetch('/api/automations', {
            headers: {
                'Authorization': `Bearer ${idToken}`
            }
        });

        if (response.status === 401) {
            // Token is invalid or expired, force logout
            localStorage.removeItem('id_token');
            localStorage.removeItem('access_token');
            window.location.href = '/login';
            return;
        }

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const automations = await response.json();
        const contentDiv = document.getElementById('content');
        contentDiv.innerHTML = '<h2>Available Automations:</h2>';
        const ul = document.createElement('ul');
        automations.forEach(auto => {
            const li = document.createElement('li');
            li.textContent = auto.name;
            ul.appendChild(li);
        });
        contentDiv.appendChild(ul);

    } catch (error) {
        console.error('Error fetching automations:', error);
        const contentDiv = document.getElementById('content');
        contentDiv.innerHTML = '<p>Error loading automations. Please try again later.</p>';
    }
}