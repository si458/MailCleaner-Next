<?php
/**
 * @license http://www.mailcleaner.net/open/licence_en.html Mailcleaner Public License
 * @package mailcleaner
 * @author Olivier Diserens, John Mertz
 * @copyright 2009, Olivier Diserens; 2023, John Mertz
 *
 * Filename table
 */

class Default_Model_DbTable_FileName extends Zend_Db_Table_Abstract
{
    protected $_name    = 'filename';

    public function __construct() {
    	$this->_db = Zend_Registry::get('writedb');
    }
}
