"use strict";
class AutomationUI {
    constructor() {
        this.automations = [];
        this.selectedAutomation = null;
        this.init();
    }
    async init() {
        await this.loadAutomations();
        this.setupEventListeners();
    }
    async loadAutomations() {
        try {
            const response = await fetch('/api/automations');
            if (!response.ok)
                throw new Error('Failed to load automations');
            this.automations = await response.json();
            this.renderAutomationSelector();
        }
        catch (error) {
            this.showError('Failed to load automations: ' + error);
        }
    }
    renderAutomationSelector() {
        const selector = document.getElementById('automation-selector');
        if (!selector)
            return;
        selector.innerHTML = '<option value="">Select an automation...</option>';
        this.automations.forEach(automation => {
            const option = document.createElement('option');
            option.value = automation.id;
            option.textContent = automation.name;
            selector.appendChild(option);
        });
    }
    setupEventListeners() {
        const selector = document.getElementById('automation-selector');
        const runButton = document.getElementById('run-button');
        selector?.addEventListener('change', (e) => {
            const target = e.target;
            this.onAutomationSelected(target.value);
        });
        runButton?.addEventListener('click', () => {
            this.runAutomation();
        });
    }
    onAutomationSelected(automationId) {
        this.selectedAutomation = this.automations.find(a => a.id === automationId) || null;
        if (this.selectedAutomation) {
            this.renderAutomationDetails();
            this.renderParameterInputs();
        }
        else {
            this.clearAutomationDetails();
        }
    }
    renderAutomationDetails() {
        const detailsDiv = document.getElementById('automation-details');
        const parametersDiv = document.getElementById('parameters-container');
        const runButton = document.getElementById('run-button');
        if (!detailsDiv || !this.selectedAutomation)
            return;
        detailsDiv.innerHTML = `
            <h3>${this.selectedAutomation.name}</h3>
            <p class="description">${this.selectedAutomation.description}</p>
        `;
        parametersDiv.style.display = 'block';
        runButton.disabled = false;
    }
    renderParameterInputs() {
        const container = document.getElementById('parameters-form');
        if (!container || !this.selectedAutomation)
            return;
        container.innerHTML = '';
        this.selectedAutomation.parameters.forEach(param => {
            const formGroup = document.createElement('div');
            formGroup.className = 'form-group';
            const label = document.createElement('label');
            label.textContent = param.label + (param.required ? ' *' : '');
            label.htmlFor = `param-${param.name}`;
            formGroup.appendChild(label);
            let input;
            switch (param.type) {
                case 'textarea':
                    input = document.createElement('textarea');
                    input.id = `param-${param.name}`;
                    input.placeholder = param.placeholder || '';
                    input.rows = 4;
                    break;
                case 'select':
                    input = document.createElement('select');
                    input.id = `param-${param.name}`;
                    param.options?.forEach(option => {
                        const optElement = document.createElement('option');
                        optElement.value = option;
                        optElement.textContent = option;
                        if (param.default === option) {
                            optElement.selected = true;
                        }
                        input.appendChild(optElement);
                    });
                    break;
                case 'checkbox':
                    input = document.createElement('input');
                    input.type = 'checkbox';
                    input.id = `param-${param.name}`;
                    input.checked = param.default || false;
                    break;
                default:
                    input = document.createElement('input');
                    input.type = 'text';
                    input.id = `param-${param.name}`;
                    input.placeholder = param.placeholder || '';
            }
            input.setAttribute('data-param-name', param.name);
            input.setAttribute('data-required', param.required.toString());
            formGroup.appendChild(input);
            container.appendChild(formGroup);
        });
    }
    clearAutomationDetails() {
        const detailsDiv = document.getElementById('automation-details');
        const parametersDiv = document.getElementById('parameters-container');
        const runButton = document.getElementById('run-button');
        if (detailsDiv)
            detailsDiv.innerHTML = '';
        if (parametersDiv)
            parametersDiv.style.display = 'none';
        if (runButton)
            runButton.disabled = true;
    }
    getParameterValues() {
        const parameters = {};
        const inputs = document.querySelectorAll('[data-param-name]');
        inputs.forEach(input => {
            const paramName = input.getAttribute('data-param-name');
            if (!paramName)
                return;
            if (input instanceof HTMLInputElement && input.type === 'checkbox') {
                parameters[paramName] = input.checked;
            }
            else if (input instanceof HTMLInputElement ||
                input instanceof HTMLTextAreaElement ||
                input instanceof HTMLSelectElement) {
                parameters[paramName] = input.value;
            }
        });
        return parameters;
    }
    validateParameters() {
        const inputs = document.querySelectorAll('[data-param-name]');
        let isValid = true;
        inputs.forEach(input => {
            const required = input.getAttribute('data-required') === 'true';
            if (required) {
                if (input instanceof HTMLInputElement && input.type === 'checkbox') {
                    // Checkboxes are always valid
                }
                else if (input instanceof HTMLInputElement ||
                    input instanceof HTMLTextAreaElement ||
                    input instanceof HTMLSelectElement) {
                    if (!input.value.trim()) {
                        input.classList.add('error');
                        isValid = false;
                    }
                    else {
                        input.classList.remove('error');
                    }
                }
            }
        });
        return isValid;
    }
    async runAutomation() {
        if (!this.selectedAutomation)
            return;
        if (!this.validateParameters()) {
            this.showError('Please fill in all required fields');
            return;
        }
        const parameters = this.getParameterValues();
        const runButton = document.getElementById('run-button');
        const outputDiv = document.getElementById('output');
        const outputContent = document.getElementById('output-content');
        if (!outputDiv || !outputContent)
            return;
        // Disable button and show loading
        runButton.disabled = true;
        runButton.textContent = 'Running...';
        outputDiv.style.display = 'block';
        outputContent.innerHTML = '<div class="loading">Executing automation...</div>';
        try {
            const response = await fetch('/api/run', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    automation_id: this.selectedAutomation.id,
                    parameters: parameters
                })
            });
            const result = await response.json();
            if (result.error) {
                this.showOutput(`Error: ${result.error}`, 'error');
            }
            else if (result.success) {
                const output = result.stdout || 'Script completed successfully!';
                this.showOutput(output, 'success');
            }
            else {
                const errorOutput = result.stderr || result.stdout || 'Script failed';
                this.showOutput(`Script failed with return code ${result.returncode}:\n${errorOutput}`, 'error');
            }
        }
        catch (error) {
            this.showOutput('Failed to execute automation: ' + error, 'error');
        }
        finally {
            runButton.disabled = false;
            runButton.textContent = 'Run Automation';
        }
    }
    showOutput(message, type) {
        const outputDiv = document.getElementById('output');
        const outputContent = document.getElementById('output-content');
        if (!outputDiv || !outputContent)
            return;
        outputDiv.style.display = 'block';
        outputContent.className = type;
        outputContent.innerText = this.escapeHtml(message);
    }
    showError(message) {
        this.showOutput(message, 'error');
    }
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerText;
    }
}
// Initialize the app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    new AutomationUI();
});
