interface Parameter {
    name: string;
    label: string;
    type: string;
    required: boolean;
    placeholder?: string;
    options?: string[];
    default?: any;
}

interface Automation {
    id: string;
    name: string;
    description: string;
    script: string;
    parameters: Parameter[];
}

class AutomationUI {
    private automations: Automation[] = [];
    private selectedAutomation: Automation | null = null;

    constructor() {
        this.init();
    }

    private async init(): Promise<void> {
        await this.loadAutomations();
        this.setupEventListeners();
    }

    private async loadAutomations(): Promise<void> {
        try {
            const response = await fetch('/api/automations');
            if (!response.ok) throw new Error('Failed to load automations');

            this.automations = await response.json();
            this.renderAutomationSelector();
        } catch (error) {
            this.showError('Failed to load automations: ' + error);
        }
    }

    private renderAutomationSelector(): void {
        const selector = document.getElementById('automation-selector') as HTMLSelectElement;
        if (!selector) return;

        selector.innerHTML = '<option value="">Select an automation...</option>';

        this.automations.forEach(automation => {
            const option = document.createElement('option');
            option.value = automation.id;
            option.textContent = automation.name;
            selector.appendChild(option);
        });
    }

    private setupEventListeners(): void {
        const selector = document.getElementById('automation-selector') as HTMLSelectElement;
        const runButton = document.getElementById('run-button') as HTMLButtonElement;

        selector?.addEventListener('change', (e) => {
            const target = e.target as HTMLSelectElement;
            this.onAutomationSelected(target.value);
        });

        runButton?.addEventListener('click', () => {
            this.runAutomation();
        });
    }

    private onAutomationSelected(automationId: string): void {
        this.selectedAutomation = this.automations.find(a => a.id === automationId) || null;

        if (this.selectedAutomation) {
            this.renderAutomationDetails();
            this.renderParameterInputs();
        } else {
            this.clearAutomationDetails();
        }
    }

    private renderAutomationDetails(): void {
        const detailsDiv = document.getElementById('automation-details');
        const parametersDiv = document.getElementById('parameters-container');
        const runButton = document.getElementById('run-button') as HTMLButtonElement;

        if (!detailsDiv || !this.selectedAutomation) return;

        detailsDiv.innerHTML = `
            <h3>${this.selectedAutomation.name}</h3>
            <p class="description">${this.selectedAutomation.description}</p>
        `;

        parametersDiv!.style.display = 'block';
        runButton.disabled = false;
    }

    private renderParameterInputs(): void {
        const container = document.getElementById('parameters-form');
        if (!container || !this.selectedAutomation) return;

        container.innerHTML = '';

        this.selectedAutomation.parameters.forEach(param => {
            const formGroup = document.createElement('div');
            formGroup.className = 'form-group';

            const label = document.createElement('label');
            label.textContent = param.label + (param.required ? ' *' : '');
            label.htmlFor = `param-${param.name}`;
            formGroup.appendChild(label);

            let input: HTMLElement;

            switch (param.type) {
                case 'textarea':
                    input = document.createElement('textarea');
                    (input as HTMLTextAreaElement).id = `param-${param.name}`;
                    (input as HTMLTextAreaElement).placeholder = param.placeholder || '';
                    (input as HTMLTextAreaElement).rows = 4;
                    break;

                case 'select':
                    input = document.createElement('select');
                    (input as HTMLSelectElement).id = `param-${param.name}`;
                    param.options?.forEach(option => {
                        const optElement = document.createElement('option');
                        optElement.value = option;
                        optElement.textContent = option;
                        if (param.default === option) {
                            optElement.selected = true;
                        }
                        (input as HTMLSelectElement).appendChild(optElement);
                    });
                    break;

                case 'checkbox':
                    input = document.createElement('input');
                    (input as HTMLInputElement).type = 'checkbox';
                    (input as HTMLInputElement).id = `param-${param.name}`;
                    (input as HTMLInputElement).checked = param.default || false;
                    break;

                default:
                    input = document.createElement('input');
                    (input as HTMLInputElement).type = 'text';
                    (input as HTMLInputElement).id = `param-${param.name}`;
                    (input as HTMLInputElement).placeholder = param.placeholder || '';
            }

            input.setAttribute('data-param-name', param.name);
            input.setAttribute('data-required', param.required.toString());
            formGroup.appendChild(input);

            container.appendChild(formGroup);
        });
    }

    private clearAutomationDetails(): void {
        const detailsDiv = document.getElementById('automation-details');
        const parametersDiv = document.getElementById('parameters-container');
        const runButton = document.getElementById('run-button') as HTMLButtonElement;

        if (detailsDiv) detailsDiv.innerHTML = '';
        if (parametersDiv) parametersDiv.style.display = 'none';
        if (runButton) runButton.disabled = true;
    }

    private getParameterValues(): Record<string, any> {
        const parameters: Record<string, any> = {};
        const inputs = document.querySelectorAll('[data-param-name]');

        inputs.forEach(input => {
            const paramName = input.getAttribute('data-param-name');
            if (!paramName) return;

            if (input instanceof HTMLInputElement && input.type === 'checkbox') {
                parameters[paramName] = input.checked;
            } else if (input instanceof HTMLInputElement ||
                       input instanceof HTMLTextAreaElement ||
                       input instanceof HTMLSelectElement) {
                parameters[paramName] = input.value;
            }
        });

        return parameters;
    }

    private validateParameters(): boolean {
        const inputs = document.querySelectorAll('[data-param-name]');
        let isValid = true;

        inputs.forEach(input => {
            const required = input.getAttribute('data-required') === 'true';

            if (required) {
                if (input instanceof HTMLInputElement && input.type === 'checkbox') {
                    // Checkboxes are always valid
                } else if (input instanceof HTMLInputElement ||
                           input instanceof HTMLTextAreaElement ||
                           input instanceof HTMLSelectElement) {
                    if (!input.value.trim()) {
                        input.classList.add('error');
                        isValid = false;
                    } else {
                        input.classList.remove('error');
                    }
                }
            }
        });

        return isValid;
    }

    private async runAutomation(): Promise<void> {
        if (!this.selectedAutomation) return;

        if (!this.validateParameters()) {
            this.showError('Please fill in all required fields');
            return;
        }

        const parameters = this.getParameterValues();
        const runButton = document.getElementById('run-button') as HTMLButtonElement;
        const outputDiv = document.getElementById('output');
        const outputContent = document.getElementById('output-content');

        if (!outputDiv || !outputContent) return;

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
            } else if (result.success) {
                const output = result.stdout || 'Script completed successfully!';
                this.showOutput(output, 'success');
            } else {
                const errorOutput = result.stderr || result.stdout || 'Script failed';
                this.showOutput(`Script failed with return code ${result.returncode}:\n${errorOutput}`, 'error');
            }
        } catch (error) {
            this.showOutput('Failed to execute automation: ' + error, 'error');
        } finally {
            runButton.disabled = false;
            runButton.textContent = 'Run Automation';
        }
    }

    private showOutput(message: string, type: 'success' | 'error'): void {
        const outputDiv = document.getElementById('output');
        const outputContent = document.getElementById('output-content');

        if (!outputDiv || !outputContent) return;

        outputDiv.style.display = 'block';
        outputContent.className = type;
        outputContent.innerText = this.escapeHtml(message);
    }

    private showError(message: string): void {
        this.showOutput(message, 'error');
    }

    private escapeHtml(text: string): string {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerText;
    }
}

// Initialize the app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    new AutomationUI();
});
