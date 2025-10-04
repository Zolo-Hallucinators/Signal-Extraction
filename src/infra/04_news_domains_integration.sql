-- Description: This code has to be run once to initial subsequent runs to update the news_dowman_nr network rule.
USE DATABASE SIGNAL_EXTRACTION_DB;
USE SCHEMA UTILS;

-- Network Rule Creation
CREATE OR REPLACE NETWORK RULE news_domains_nr -- hard coded in ensure_network_rule_for_domain()
    MODE = EGRESS   -- means outbound traffice FROM snowflake to external is allowed.
    TYPE = HOST_PORT
    VALUE_LIST = ('finance.yahoo.com', 'www.activistpost.com')
    ;

-- NR 1
CREATE OR REPLACE NETWORK RULE news_domains_nr_1
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'www.breitbart.com', 'kevinmd.com', 'biztoc.com', 'www.forbes.com', 'www.globenewswire.com',
        'finance.yahoo.com', 'nypost.com', 'lwn.net', 'fortune.com', 'www.cbssports.com', 'www.tenable.com',
        'www.telecomtv.com', 'economictimes.indiatimes.com', 'www.theregister.com', 'hackread.com',
        'www.bleepingcomputer.com', 'www.ign.com', 'www.marketwatch.com', 'www.infosecurity-magazine.com',
        'www.nakedcapitalism.com', 'prtimes.jp', 'www.securityweek.com', 'www.ndtvprofit.com',
        'financialpost.com', 'www.hospitalitynet.org', 'www.etfdailynews.com', 'www.ccn.com',
        'www.ciodive.com', 'securityaffairs.com', 'slashdot.org', 'cnalifestyle.channelnewsasia.com',
        'freerepublic.com', 'cointelegraph.com', 'www.zdnet.com', 'www.channelnewsasia.com',
        'consent.yahoo.com', 'www.pymnts.com', 'siliconangle.com', 'www.sqlservercentral.com',
        'genomebiology.biomedcentral.com', 'observer.com', 'databreaches.net', 'www.ibtimes.com',
        'www.nextgov.com', 'www.yahoo.com', 'decrypt.co', 'japantoday.com', 'newrepublic.com',
        'www.newser.com', 'thefly.com', 'www.mmafighting.com', 'abcnews.go.com', 'www.itnews.com.au',
        'www.bostonherald.com', 'tech.slashdot.org', 'macdailynews.com', 'techcrunch.com',
        'www.digitaljournal.com', 'www.esquire.com', 'www.rt.com', 'www.investopedia.com',
        'awealthofcommonsense.com', 'www.pcgamer.com', 'gizmodo.com', 'thekenyatimes.com',
        'www.businessinsider.com', 'www.androidheadlines.com', 'www.cnbc.com', 'en.protothema.gr',
        'www.helpnetsecurity.com', 'qz.com', 'aquariumdrunkard.com', 'thehackernews.com', 'ca.news.yahoo.com',
        'www.techradar.com', 'www.irishtimes.com', 'english.khabarhub.com', 'www.channelstv.com',
        'www.thestar.com.my', 'www.exchangewire.com', 'pypi.org', 'www.abc.net.au', 'www.rte.ie',
        'dpa-international.com', 'digiday.com', 'news.sky.com', 'www.bbc.co.uk', 'www.bbc.com',
        'www.nbcsports.com', 'www.espn.com', 'sports.yahoo.com', 'www.wowhead.com', 'www.utilitydive.com',
        'www.livemint.com', 'www.thestreet.com', 'www.thewrap.com', 'www.tomshardware.com', 'www.cmswire.com',
        'www.commondreams.org', 'amplifypartners.com', 'www.finextra.com', 'ritholtz.com', 'www.dazeddigital.com',
        'www.pitpass.com', 'www.infoq.com', 'www.lemis.com', 'post.rlsbb.to', 'www.digitimes.com',
        'uk.news.yahoo.com', 'wccftech.com', 'hypebeast.com', 'cryptoslate.com', 'www.postgresql.org',
        'isc.sans.edu', 'www.newsbtc.com', 'deadline.com', 'histalk2.com', 'www.msnbc.com', 'www.benzinga.com',
        'crooksandliars.com', 'www.theverge.com', 'dailycaller.com', 'wwd.com', 'techpinions.com',
        'seclists.org', 'www.thegoodphight.com', 'www.cinemablend.com', 'www.fark.com', 'cacm.acm.org',
        'mymodernmet.com', 'engineering.fb.com', 'garrybargsley.com', 'bitcoinist.com', 'www.microsoft.com',
        'www.tuko.co.ke', 'www.gamespot.com', 'www.techdirt.com', 'www.barchart.com', 'www.activistpost.com',
        'www.techmonitor.ai', 'www.techtarget.com', 'huijzer.xyz', 'www.constellationr.com', 'indianexpress.com',
        'www.gov.uk', 'theconversation.com', 'theweek.com', 'bringatrailer.com', 'www.vox.com',
        'www.investors.com', 'zerotomastery.io', 'www.wealthmanagement.com', 'www.kqed.org',
        'www.foxsports.com', 'www.cbsnews.com', 'www.huffpost.com', 'www.statesman.com'
    );

-- External Access Integration (Mandatory one-time creation needed)
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION news_domains_integration -- hard coded in ensure_network_rule_for_domain()
    ALLOWED_NETWORK_RULES = (
        news_domains_nr
        -- ,news_domains_nr_1
    )
    ENABLED = TRUE
    COMMENT = 'Dynamic Integration to add network rules through code'
    ;

-- To view the latest changes made to the integration
DESCRIBE EXTERNAL ACCESS INTEGRATION news_domains_integration;
DESCRIBE NETWORK RULE news_domains_nr; --value_list only able to be retrieved from here.
SHOW NETWORK RULES LIKE 'news_domains_nr';

-- [Not Working] Throwing 'SQL compilation error'
-- SELECT VALUE_LIST 
-- FROM INFORMATION_SCHEMA.NETWORK_RULES 
-- WHERE NETWORK_RULE_NAME = 'news_domains_nr';