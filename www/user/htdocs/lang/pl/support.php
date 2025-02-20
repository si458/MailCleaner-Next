<?php

$txt['SFALSENEGTITLE'] = "BŁĘDNIE NEGATYWNE";
$txt['SFALSENEGSUBTITLE'] = "Czy dostałeś wiadomość, którą uznajesz za spam?";
$txt['SVERIFYPASS'] = "Sprawdź, że wiadomość została przeprocesowana przez filtr Mailcleaner za pomocą przeglądania nagłówków e-maila.";
$txt['SFALSEPOSTITLE'] = "BŁĘDNIE POZYTYWNE";
$txt['SFALSEPOSSUB1TITLE'] = "Nie otrzymałeś wiadomości, która nie powinna dotrzeć?";
$txt['SFALSEPOSSUB1POINT1'] = "adres docelowy użyty przez nadawcę jest prawidłowy";
$txt['SFALSEPOSSUB2TITLE'] = "Wiadomość została uznana za spam a Ty nie rozumiesz dlaczego?";
$txt['SFALSEPOSSUB3TITLE'] = "Listy mailingowe";
$txt['SOTHERTITLE'] = "INNE PROBLEMY";
$txt['FAQTITLE'] = "Zrozumienie działania Mailclenaera";
$txt['DOCTITLE'] = "Pomoc w zakresie interfejsu użytkownika";
$txt['WEBDOCTITLE'] = "Dokumentacja online";
$txt['SMCLOGTITLE'] = "W nagłówkach widać następujące wpisy dotyczące Mailcleanera:";
$txt['SMCLOGLINE1'] = "Otrzymane: Od mailcleaner.net (mechanizm filtrujący)";
$txt['SMCLOGLINE2'] = "przez mailcleaner.net z esmtp (mechanizm poczty przychodzącej)";
$txt['SMCFILTERINGLOG'] = "Rezultat filtrowania: Punktacja X-Mailcleaner: oooo";
$txt['SFALSEPOSSUB1POINT2'] = "e-mail może być przetworzony (zajmie to kilka minut)";
$txt['DOCUMENTATION'] = "
                         <ul>
<li> <h2>Kwarantanna widok/działania</h2>
<ul>
<li> <h3> Adres: </h3>wybierz adres, dla którego chcesz widzieć wiadomości poddane kwarantannie.</li>
<li> <h3> Zwolnij z kwarantanny (<img src = \"/templates/$template/images/force.gif\" align = \"top\" alt = \"\">): </h3>
Kliknij tę ikonę, aby zwolnić wiadomość z kwarantanny. Zostanie ona przekazana bezpośrednio do Twojej skrzynki odbiorczej.</li>
<li> <h3> Wyświetl informacje (<img src = \"/templates/$template/images/why.gif\" align = \"top\" alt = \"\">): </h3>
Jeśli chcesz zobaczyć, dlaczego wiadomość została wykryta jako spam, kliknij tę ikonę. Zobaczysz kryteria Mailcleaner z odpowiadającymi im wynikami. Wynik 5 lub wyższy sprawi, że wiadomość zostanie uznana za spam.</li>
<li> <h3> Wyślij do analizy (<img src = \"/templates/$template/images/analyse.gif\" align = \"top\" alt = \"\">): </h3>
W przypadku oznaczenia jako spam poprawnej wiadomości kliknij ikonę, aby przesłać informację do swojego administratora.</li>
<li> <h3> Opcje filtru: </h3>
Dostępne są niektóre opcje filtrowania, które umożliwiają przeszukiwanie kwarantanny. Liczba dni w kwarantannie, liczba wiadomości na stronie i pola wyszukiwania tematu/miejsca docelowego. Wypełnij te, których chcesz użyć i kliknij „Odśwież”, aby zastosować.</li>
<li> <h3> Akcja: </h3>
Możesz wyczyścić (<img src = \"/templates/$template/images/trash.gif\" align = \"top\" alt = \"\">) całą kwarantannę, kiedy tylko chcesz. Pamiętaj, że kwarantanny są okresowo automatycznie czyszczone przez system. Ta opcja pozwala ci to robić kiedy tylko chcesz. Możesz również poprosić o podsumowanie (<img src = \"/templates/$template/images/summary.gif\" align = \"top\" alt = \"\">) kwarantanny. To jest to samo podsumowanie, które jest wysyłane okresowo. Ta opcja pozwala tylko o to poprosić.</li>
</ul>
</li>
<li> <h2> Parametry </h2>
<ul>
<li> <h3> Ustawienia języka użytkownika: </h3>
Wybierz tutaj swój język podstawowy. Wpłynie to na interfejs, podsumowania i raporty.</li>
<li> <h3> Zbiorczy adres/alias: </h3>
Jeśli masz wiele adresów lub aliasów do zagregowania w interfejsie Mailcleaner, po prostu użyj znaku plus (<img src = \"/templates/$template/images/plus.gif\" align = \"top\" alt = \"\">) i minus ( <img src = \"/templates/$template/images/minus.gif\" align = \"top\" alt = \"\">) aby dodać lub usunąć adresy.</li>
</ul>
</li>
<li> <h2> Ustawienia dla poszczególnych adresów: </h2>
Niektóre ustawienia można skonfigurować dla każdego adresu.
<ul>
<li> <h3> Przycisk Zastosuj do wszystkich: </h3>
Użyj tego, aby zastosować zmiany do wszystkich adresów.
</li>
<li> <h3> Tryb dostarczania spamu: </h3>
Wybierz, co ma robić Mailcleaner z wiadomościami wykrytymi jako spam.
<ul>
<li> <h4> Kwarantanna: </h4> wiadomości są przechowywane w kwarantannie i okresowo usuwane. </li>
<li> <h4> Oznakowanie: </h4> Spam nie będzie blokowany, ale w polu tematu zostanie dodany znak. </li>
<li> <h4> Porzuć: </h4> Spam zostanie po prostu odrzucony. Używaj tego ostrożnie, ponieważ może to doprowadzić do utraty wiadomości. </li>
</ul>
</li>
<li> <h3> Kwarantanna odbija się: </h3>
Ta opcja spowoduje, że Mailcleaner podda kwarantannie odrzucone wiadomości i powiadomienia o niepowodzeniach e-mail. Może to być przydatne, jeśli jesteś ofiarą masowych odsyłaczy e-maili z powodu na przykład rozpowszechnionych wirusów. Powinno to być aktywowane tylko na krótkie okresy czasu, ponieważ jest to bardzo niebezpieczne.</li>
<li> <h3> Oznakowanie spamu: </h3>
Wybierz i dostosuj wiadomość wyświetlaną w polu tematu oznaczonego spamu. Nie ma to znaczenia, jeśli wybrałeś tryb dostarczania kwarantanny.
</li>
<li> <h3> Częstotliwość raportowania: </h3>
Wybierz częstotliwość otrzymywania podsumowań kwarantanny. W tym przedziale czasu otrzymasz wiadomość e-mail z dużą ilością spamu wykrytego i przechowywanego w kwarantannie. </li> </ul> </li>
</ul>";
$txt['WEBDOC'] = "<ul> <li> Więcej informacji i dokumentacji można znaleźć w naszej witrynie internetowej: <a href=\"https://wiki2.mailcleaner.net/doku.php/documentation:userfaq\" target=\"_blank\"> Dokumentacja użytkownika Mailcleaner </a> </li> </ul>";
$txt['FAQ'] = "
               <ul>
                 <li> <h2> Co robi Mailcleaner? </h2>
                      Mailcleaner to filtr poczty e-mail, który sprawdza wiadomości przychodzące pod kątem znanego spamu, wirusów i innych niebezpiecznych treści, unikając nawet przedostania się ich na pulpit. Jest to rozwiązanie po stronie serwera, co oznacza, że nie musisz mieć zainstalowanego w systemie żadnego oprogramowania do filtrowania wiadomości e-mail. W rzeczywistości jest to wykonywane przez dostawcę konta e-mail. Dzięki interfejsowi internetowemu jesteś bezpośrednio połączony z filtrem Mailcleaner, za pomocą którego możesz dostroić niektóre ustawienia filtra i zobaczyć cały zablokowany spam.
                 </li>
                 <li> <h2> Co to jest spam? </h2>
                      Spam to niechciane lub niepożądane wiadomości e-mail. Zwykle używane do reklam, te wiadomości mogą szybko zapełnić skrzynkę odbiorczą. Wiadomości spam na ogół nie są niebezpieczne, ale mimo to naprawdę irytujące.
                 </li>
                 <li> <h2> Co to są wirusy i niebezpieczne treści? </h2>
                      Wirusy to oprogramowanie, które może wykorzystywać i pozwalać przejąć kontrolę nad komputerem. Mogą one zostać wysłane do Ciebie w wiadomości e-mail jako załączniki i zarazić system po otwarciu (niektóre można nawet uruchomić bez ich otwierania). Niebezpieczne treści są często niewidoczne a można je włączyć w bardzo inteligentny sposób, ukrywając bezpośrednio w treści wiadomości, a nawet atakując z zewnątrz za pomocą odsyłacza do wiadomości e-mail. Są one bardzo trudne do wykrycia przy użyciu standardowych filtrów poczty e-mail, ponieważ prawdziwy wirus tak naprawdę nie jest zawarty w wiadomości. Mailcleaner przeprowadza więcej kontroli, aby zapobiec przedostawaniu się potencjalnie ryzykownych wiadomości e-mail do Twojej skrzynki odbiorczej.
                 </li>
                 <li> <h2> Kryteria antyspamowe Mailcleaner </h2>
                      Mailcleaner wykorzystuje szereg testów w celu wykrywania spamu z możliwie największą dokładnością. Wykorzystuje między innymi proste dopasowywanie słów kluczowych lub fraz kluczowych, ogólnoświatowe bazy danych spamu i obliczenia tokenów statystycznych. Suma wszystkich tych kryteriów daje ogólny wynik dla każdej wiadomości, na podstawie której Mailcleaner podejmie ostateczną decyzję. Ponieważ spam naprawdę szybko ulega zmianą, zasady te są również dostosowywane tak szybko, jak to możliwe. Zadaniem Mailcleanera jest utrzymanie tych ustawień tak dobrych, jak to tylko możliwe.
                 </li>
                 <li> <h2> Błędy </h2>
                      Ponieważ Mailcleaner jest zautomatyzowanym systemem filtrującym, jest również podatny na błędy. Zasadniczo istnieją dwa rodzaje błędów, które mogą być generowane przez Mailcleaner:
                      <ul>
                       <li> <h3> Fałszywe negatywy </h3> Fałszywe negatywy to wiadomości będące spamem, którym udało się przedostać przez filtr Mailcleaner i dotrzeć do Twojej skrzynki odbiorczej bez wykrycia. Są irytujące, ale tak długo, jak zdarzają się stosunkowo rzadko, żadna znacząca strata nie zostanie poniesiona w związku z produktywnością w pracy. Pamiętasz, kiedy co tydzień otrzymywałeś tylko kilka wiadomości spamowych? Mailcleaner może pomóc Ci wrócić przynajmniej do tego punktu.
                       </li>
                       <li> <h3> Fałszywe alarmy </h3> Są to bardziej irytujące błędy, ponieważ są wynikiem blokowania prawidłowych wiadomości e-mail przez system. Jeśli nie jesteś wystarczająco czujny i nie sprawdzasz dokładnie kwarantanny lub raportów, może to doprowadzić do utraty ważnych wiadomości. Mailcleaner jest zoptymalizowany pod kątem maksymalnego ograniczenia tych błędów. Jednak, chociaż jest to bardzo rzadkie, może się to zdarzyć. Dlatego Mailcleaner obejmuje dostęp do kwarantanny w czasie rzeczywistym i okresowe raporty, które pomagają zminimalizować ryzyko utraty wiadomości.
                       </li>
                      </ul>
                  </li>
                  <li> <h2> Co możesz zrobić, aby poprawić Mailcleaner </h2>
                      W przypadku błędów Mailcleaner najlepsza pomóc to poprawić filtr, wysyłając informację do administratora. Nie myśl, że najlepszym rozwiązaniem są tylko nadawcy z białej lub czarnej listy, ponieważ jest to tylko szybki, ale brudny sposób (sprawdź to, aby uzyskać więcej informacji). Chociaż czasami jest to jedyna możliwość, zawsze lepiej jest znaleźć prawdziwą przyczynę błędu i ją poprawić. Mogą to zrobić tylko osoby techniczne, więc nie wahaj się wysyłać opinii po błędach do swojego administratora.
                  </li>
                </ul>";
$txt['SOTHER'] = "Czy masz inne problemy z odbiorem wiadomości e-mail, a powyższe procedury nie przyniosły pozytywnych rezultatów? Jeśli tak, skontaktuj się z Centrum Analiz Mailcleaner, wypełniając ten formularz.";
$txt['SFALSEPOSSUB3'] = "Czasami niektóre listy mailingowe są blokowane przez Mailcleaner. Wynika to z ich formatowania, które często jest bardzo podobne do spamu. Możesz poprosić o analizę tych wiadomości, jak wyjaśniono powyżej, a nasze centrum analiz zadba o umieszczenie takich list mailingowych na białych listach, aby zapobiec ich blokowaniu w przyszłości.";
$txt['SFALSEPOSSUB2'] = "Na liście kwarantann możesz wyświetlić kryteria, według których Mailcleaner uznał wiadomość za spam za pośrednictwem <img src = \"/templates /$template/images/support/agues.gif\" align = \"middle\" alt = \"\"> przycisku. Jeśli uważasz, że te kryteria nie są uzasadnione, możesz poprosić nasze centrum analiz o weryfikację, klikając <img src = \"/templates/$template/images/support/analyse.gif\" align = \"middle\" alt = \" \">. Możesz także zwolnić wiadomość, klikając przycisk <img src = \"/templates/$template/images/support/force.gif\" align = \"middle\" alt = \"\">.";
$txt['SFALSEPOSSUB1'] = "Możesz sprawdzić, czy wiadomość została zablokowana przez Mailcleaner w interfejsie internetowym użytkownika, pod nagłówkiem „Kwarantanna”. Jeśli nie znajdziesz go na liście kwarantanny, sprawdź następujące punkty:";
$txt['SFALSENEGTUTOR'] = "Jeśli naprawdę okaże się, że wiadomość jest spamem, prześlij ją na adres spam@mailcleaner.net lub jeszcze lepiej, jeśli program pocztowy na to pozwala, wybierz opcję „Prześlij jako załącznik”, aby zachować nagłówki wiadomości e-mail wiadomości w stanie nienaruszonym. Nasze centrum analityczne rozpowszechni treść wiadomości i odpowiednio dostosuje kryteria filtrowania Mailcleanera, tak aby wszyscy użytkownicy Mailcleanera skorzystali z analizy.";
