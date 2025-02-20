<?php

/**
 * @license http://www.mailcleaner.net/open/licence_en.html Mailcleaner Public License
 * @package mailcleaner
 * @author Olivier Diserens, John Mertz
 * @copyright 2009, Olivier Diserens; 2023, John Mertz
 *
 * Domain general settings form
 */

class Default_Form_DomainOutgoing extends Zend_Form
{
    protected $_domain;
    private $_mta;
    protected $_panelname = 'outgoing';
    public $dkim_domain = null;
    public $dkim_selector = null;
    public $dkim_pubkey = null;

    public function __construct($domain)
    {
        $this->_domain = $domain;
        $this->_mta = new Default_Model_MtaConfig();
        $this->_mta->find(1);

        parent::__construct();
    }

    public function init()
    {
        $this->setMethod('post');

        $t = Zend_Registry::get('translate');

        $this->setAttrib('id', 'domain_form');
        $panellist = new Zend_Form_Element_Select('domainpanel', [
            'required' => false,
            'filters' => ['StringTrim']
        ]);
        ## TODO: add specific validator
        $panellist->addValidator(new Zend_Validate_Alnum());

        foreach ($this->_domain->getConfigPanels() as $panel => $panelname) {
            $panellist->addMultiOption($panel, $panelname);
        }
        $panellist->setValue($this->_panelname);
        $this->addElement($panellist);

        $panel = new Zend_Form_Element_Hidden('panel');
        $panel->setValue($this->_panelname);
        $this->addElement($panel);
        $name = new Zend_Form_Element_Hidden('name');
        $name->setValue($this->_domain->getParam('name'));
        $this->addElement($name);

        $allowsmtpauth = new Zend_Form_Element_Checkbox('smtpauth', [
            'label' => $t->_('Allow SMTP auth') . " :",
            'title' => $t->_("Allow a domain to use authenticated outgoing relay.\nOnly administrator can change that."),
            'uncheckedValue' => "0",
            'checkedValue' => "1",
        ]);
        // Only admin can enable outgoing relay
        $user_role = Zend_Registry::get('user')->getUserType();
        if ($user_role != 'administrator') {
            $allowsmtpauth->setAttrib('disabled', true);
            $allowsmtpauth->setAttrib('readonly', true);
        }

        if ($this->_domain->getPref('allow_smtp_auth')) {
            $allowsmtpauth->setChecked(true);
        }
        $this->addElement($allowsmtpauth);

        $smtpauthcachetime = new Zend_Form_Element_Text('smtp_auth_cachetime', [
            'label' => $t->_('SMTP authentication cache time') . " :",
            'required' => false,
            'size' => 8,
            'class' => 'fieldrighted',
            'filters' => ['Alnum', 'StringTrim']
        ]);
        $smtpauthcachetime->setValue($this->_domain->getPref('smtp_auth_cachetime'));
        $smtpauthcachetime->addValidator(new Zend_Validate_Int());
        $this->addElement($smtpauthcachetime);

        $require_outgoing_tls = new Zend_Form_Element_Checkbox('require_outgoing_tls', [
            'label' => $t->_('Forbid unencrypted outgoing SMTP sessions') . " :",
            'title' => $t->_("Accept only crypted SMTP sessions for outgoing relay"),
            'uncheckedValue' => "0",
            'checkedValue' => "1",
        ]);
        if ($this->_domain->getPref('require_outgoing_tls')) {
            $require_outgoing_tls->setChecked(true);
        }
        $this->addElement($require_outgoing_tls);

        $batv_check = new Zend_Form_Element_Checkbox('batv_check', [
            'label' => $t->_('Enable BATV') . " :",
            'uncheckedValue' => "0",
            'checkedValue' => "1",
        ]);

        if ($this->_domain->getPref('batv_check')) {
            $batv_check->setChecked(true);
        }
        $this->addElement($batv_check);

        $batv_secret = new Zend_Form_Element_Text('batv_secret', [
            'label' => $t->_('BATV key') . " :",
            'required' => false,
            'size' => 30,
            'filters' => ['StringTrim']
        ]);
        $batv_secret->setValue($this->_domain->getPref('batv_secret'));
        $this->addElement($batv_secret);
        if (!$this->_domain->getPref('batv_check')) {
            $batv_secret->setAttrib('readonly', 'readonly');
        }

        $dkim_signature = new Zend_Form_Element_Select('dkim_signature', [
            'label' => $t->_('DKIM signing') . " :",
            'title' => $t->_("Enables the DKIM signing"),
            'required' => false,
            'filters' => ['StringTrim']
        ]);

        $dkim_signature->addMultiOption('_none', 'None');

        if ($this->_mta->getParam('dkim_default_domain') != '') {
            $dkim_signature->addMultiOption('_default', 'Default domain (' . $this->_mta->getParam('dkim_default_domain') . ')');
        }
        if ($this->_domain->getParam('name') != '__global__') {
            $dkim_signature->addMultiOption($this->_domain->getParam('name'), 'This domain (' . $this->_domain->getParam('name') . ')');
        }
        $dkim_signature->addMultiOption('_custom', 'Custom');

        $dkim_signature->setValue('_none');
        if (
            $this->_domain->getPref('dkim_domain') == '_default' ||
            ($this->_domain->getPref('dkim_domain') == $this->_mta->getParam('dkim_default_domain') &&
                $this->_domain->getPref('dkim_selector') == $this->_mta->getParam('dkim_default_selector'))
        ) {
            $dkim_signature->setValue('_default');
        } else if ($this->_domain->getPref('dkim_domain') == $this->_domain->getParam('name')) {
            $dkim_signature->setValue($this->_domain->getParam('name'));
        } else if ($this->_domain->getPref('dkim_domain') != '') {
            $dkim_signature->setValue('_custom');
        }
        $this->addElement($dkim_signature);

        $dkim_domain = new Zend_Form_Element_Text('dkim_domain', [
            'label' => $t->_('Domain') . " :",
            'required' => false,
            'size' => 30,
            'filters' => ['StringTrim']
        ]);
        $dkim_domain->setValue($this->_domain->getPref('dkim_domain'));
        $this->addElement($dkim_domain);

        $dkim_selector = new Zend_Form_Element_Text('dkim_selector', [
            'label' => $t->_('Selector') . " :",
            'required' => false,
            'size' => 30,
            'filters' => ['StringTrim']
        ]);
        $dkim_selector->setValue($this->_domain->getPref('dkim_selector'));
        $this->addElement($dkim_selector);

        $dkim_pkey = new Zend_Form_Element_Textarea('dkim_pkey', [
            'label' => $t->_('Private key') . " :",
            'required' => false,
            'class' => 'pki_privatekey',
            'rows' => 7,
            'cols' => 50
        ]);
        $dkim_pkey->setValue($this->_domain->getPref('dkim_pkey'));
        require_once 'Validate/PKIPrivateKey.php';
        $dkim_pkey->addValidator(new Validate_PKIPrivateKey());
        $this->addElement($dkim_pkey);

        $submit = new Zend_Form_Element_Submit('submit', ['label' => $t->_('Submit')]);
        $this->addElement($submit);

        $this->setDKIMValues();



        $relay_smarthost = new Zend_Form_Element_Checkbox('relay_smarthost', [
            'label' => $t->_('Relay via Smarthost') . " :",
            'title' => $t->_("The relayed mails sent to domains that are not hosted on this server will be sent to the smarthost.\nOnly administrator can change that."),
            'uncheckedValue' => "0",
            'checkedValue' => "1",
        ]);
        // Only admin can enable outgoing relay
        $user_role = Zend_Registry::get('user')->getUserType();
        if ($user_role != 'administrator') {
            $relay_smarthost->setAttrib('disabled', true);
            $relay_smarthost->setAttrib('readonly', true);
        }

        if ($this->_domain->getParam('relay_smarthost')) {
            $relay_smarthost->setChecked(true);
        }
        $this->addElement($relay_smarthost);

        require_once('Validate/SMTPHostList.php');
        $servers_smarthost = new Zend_Form_Element_Textarea('servers_smarthost', [
            'label'    =>  $t->_('Server Realy Smarthost') . " :",
            'title' => $t->_("Name or IP address of the smarthost server to relay to"),
            'required'   => false,
            'rows' => 5,
            'cols' => 30,
            'filters'    => ['StringToLower', 'StringTrim']
        ]);
        $servers_smarthost->addValidator(new Validate_SMTPHostList());
        $servers_smarthost->setValue($this->_domain->getDestinationFieldString_smarthost());
        $this->addElement($servers_smarthost);

        $port_smarthost = new  Zend_Form_Element_Text('port_smarthost', [
            'label'    => $t->_('Destination port') . " :",
            'required' => false,
            'size' => 4,
            'filters'    => ['Alnum', 'StringTrim']
        ]);
        $port_smarthost->setValue($this->_domain->getDestinationPort_smarthost());
        $port_smarthost->addValidator(new Zend_Validate_Int());
        $this->addElement($port_smarthost);

        $multiple_smarthost = new Zend_Form_Element_Select('multiple_smarthost', [
            'label'      => $t->_('Use multiple servers as') . " :",
            'title' => $t->_("Choose method to deliver mails to destination server"),
            'required'   => false,
            'filters'    => ['StringTrim']
        ]);

        foreach ($this->_domain->getDestinationActionOptions() as $key => $value) {
            $multiple_smarthost->addMultiOption($key, $t->_($key));
            $options = $this->_domain->getDestinationActionOptions();
            if (in_array($options[$key], $this->_domain->getActiveDestinationOptions())) {
                $multiple_smarthost->setValue($key);
            }
        }
        #$multiple_smarthost->setValue('');
        $this->addElement($multiple_smarthost);
    }

    public function setParams($request, $domain)
    {
        $user_role = Zend_Registry::get('user')->getUserType();
        if ($user_role == 'administrator') {
            $domain->setPref('allow_smtp_auth', $request->getParam('smtpauth'));
        }
        $domain->setPref('smtp_auth_cachetime', $request->getParam('smtp_auth_cachetime'));
        $domain->setPref('require_outgoing_tls', $request->getParam('require_outgoing_tls'));
        $domain->setPref('batv_check', $request->getParam('batv_check'));
        $batv_secret = $this->getElement('batv_secret');
        if ($request->getParam('batv_secret') != '') {
            $domain->setPref('batv_secret', $request->getParam('batv_secret'));
            $batv_secret->setValue($domain->getPref('batv_secret'));
        } else {
            if ($request->getParam('batv_check')) {
                $domain->setPref('batv_secret', $this->rand_string(20));
                $batv_secret->setValue($domain->getPref('batv_secret'));
            }
        }
        if (!$request->getParam('batv_check')) {
            $batv_secret->setAttrib('readonly', 'readonly');
        } else {
            $batv_secret->setAttrib('readonly', null);
        }

        $allrequired = true;
        switch ($request->getParam('dkim_signature')) {
            case '_none':
                $domain->setPref('dkim_domain', '');
                break;
            case '_default':
                $domain->setPref('dkim_domain', $this->_mta->getParam('dkim_default_domain'));
                $domain->setPref('dkim_selector', $this->_mta->getParam('dkim_default_selector'));
                break;
            case $this->_domain->getParam('name'):
                $domain->setPref('dkim_domain', $this->_domain->getParam('name'));
                if ($request->getParam('dkim_selector') == '') {
                    $this->getElement('dkim_selector')->addError('Cannot be empty');
                    $allrequired = false;
                }
                $domain->setPref('dkim_selector', $request->getParam('dkim_selector'));
                if ($request->getParam('dkim_pkey') == '') {
                    $this->getElement('dkim_selector')->addError('Cannot be empty');
                    $allrequired = false;
                }
                $domain->setPref('dkim_pkey', $request->getParam('dkim_pkey'));
                break;
            default:
                $domain->setPref('dkim_domain', $request->getParam('dkim_domain'));
                if ($request->getParam('dkim_domain') == '') {
                    $this->getElement('dkim_domain')->addError('Cannot be empty');
                    $allrequired = false;
                }
                $domain->setPref('dkim_selector', $request->getParam('dkim_selector'));
                if ($request->getParam('dkim_selector') == '') {
                    $this->getElement('dkim_selector')->addError('Cannot be empty');
                    $allrequired = false;
                }
                $domain->setPref('dkim_pkey', $request->getParam('dkim_pkey'));
                if ($request->getParam('dkim_pkey') == '') {
                    $this->getElement('dkim_pkey')->addError('Cannot be empty');
                    $allrequired = false;
                }
        }

        if (!$allrequired) {
            throw new Exception('Not all required field provided');
        }
        $this->setDKIMValues();

        if ($user_role == 'administrator') {
            $domain->setParam('relay_smarthost', $request->getParam('relay_smarthost'));
        }

        $domain->setDestinationServersFieldString_smarthost($request->getParam('servers_smarthost'));
        $domain->setDestinationPort_smarthost($request->getParam('port_smarthost'));
        $domain->setDestinationOption_smarthost($request->getParam('multiple_smarthost'));

        return true;
    }

    private function rand_string($length)
    {
        $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

        $size = strlen($chars);
        $str = '';
        for ($i = 0; $i < $length; $i++) {
            $str .= $chars[rand(0, $size - 1)];
        }

        return $str;
    }

    private function setDKIMValues()
    {
        $key = new Default_Model_PKI();

        if (
            $this->_domain->getPref('dkim_domain') == '_default' ||
            ($this->_domain->getPref('dkim_domain') == $this->_mta->getParam('dkim_default_domain') &&
                $this->_domain->getPref('dkim_selector') == $this->_mta->getParam('dkim_default_selector'))
        ) {
            $this->dkim_domain = $this->_mta->getParam('dkim_default_domain');
            $this->dkim_selector = $this->_mta->getParam('dkim_default_selector');
            $key->setPrivateKey($this->_mta->getParam('dkim_default_pkey'));
            $this->dkim_pubkey = $key->getPublicKeyNoPEM();
            return;
        } else if ($this->_domain->getPref('dkim_domain') != '') {
            $this->dkim_domain = $this->_domain->getPref('dkim_domain');
            $this->dkim_selector = $this->_domain->getPref('dkim_selector');
            $key->setPrivateKey($this->_domain->getPref('dkim_pkey'));
            $this->dkim_pubkey = $key->getPublicKeyNoPEM();
            return;
        }
        $this->dkim_domain = null;
        $this->dkim_selector = null;
        $this->dkim_pubkey = null;
    }
}
