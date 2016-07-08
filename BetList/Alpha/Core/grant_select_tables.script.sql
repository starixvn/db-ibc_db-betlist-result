--@DBAGE
use bodb02
go
GRANT SELECT ON bettransm TO bodbDownlineNet;
GRANT SELECT ON bettransm TO bodbDownlineNetView;

GO
GRANT SELECT ON bettransg TO bodbDownlineNet;
GRANT SELECT ON bettransg TO bodbDownlineNetView;
GO

GRANT SELECT ON bettransm14 TO bodbDownlineNet;
GRANT SELECT ON bettransm14 TO bodbDownlineNetView;
GO

GRANT SELECT ON bettransg14 TO bodbDownlineNet;
GRANT SELECT ON bettransg14 TO bodbDownlineNetView;
GO


--@DBEXT
use bodb02
go
GRANT SELECT ON bettransm TO bodbDownlineNet;
GRANT SELECT ON bettransm TO bodbDownlineNetView;

GO
GRANT SELECT ON bettransg TO bodbDownlineNet;
GRANT SELECT ON bettransg TO bodbDownlineNetView;
GO

GRANT SELECT ON bettransm14 TO bodbDownlineNet;
GRANT SELECT ON bettransm14 TO bodbDownlineNetView;
GO

GRANT SELECT ON bettransg14 TO bodbDownlineNet;
GRANT SELECT ON bettransg14 TO bodbDownlineNetView;
GO

 --@DBARC
use bodb_Archive
go
GRANT SELECT ON bettransm TO bodbDownlineNet;
GRANT SELECT ON bettransm TO bodbDownlineNetView;

GO
GRANT SELECT ON bettransg TO bodbDownlineNet;
GRANT SELECT ON bettransg TO bodbDownlineNetView;
GO

--@DB053
USE bodb02
GO

GRANT SELECT ON SportBettypeMatrix TO bodbDownlineNet;
GRANT SELECT ON SportBettypeMatrix TO bodbDownlineNetView;

 