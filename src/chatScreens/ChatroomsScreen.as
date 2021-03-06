package chatScreens
{
	import feathers.controls.Alert;
	import feathers.controls.Button;
	import feathers.controls.ImageLoader;
	import feathers.controls.List;
	import feathers.controls.PanelScreen;
	import feathers.controls.renderers.DefaultListItemRenderer;
	import feathers.data.ListCollection;
	import feathers.events.FeathersEventType;
	import feathers.layout.VerticalLayout;
	import feathers.layout.VerticalLayoutData;

	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;

	import starling.display.DisplayObject;
	import starling.events.Event;

	import utils.NavigatorData;
	import utils.ProfileManager;

	public class ChatroomsScreen extends PanelScreen
	{
		public static const GO_CHAT:String = "goChat";
		public static const GO_LOGIN:String = "goLogin";

		private var alert:Alert;
		private var roomsList:List;

		protected var _data:NavigatorData;

		public function get data():NavigatorData
		{
			return this._data;
		}

		public function set data(value:NavigatorData):void
		{
			this._data = value;
		}

		override protected function initialize():void
		{
			super.initialize();

			this.title = "Chat Rooms";
			this.layout = new VerticalLayout();

			var menuButton:Button = new Button();
			menuButton.addEventListener(starling.events.Event.TRIGGERED, function ():void
			{
				dispatchEventWith(Main.OPEN_MENU);
			});
			menuButton.styleNameList.add("menu-button");
			this.headerProperties.leftItems = new <DisplayObject>[menuButton];

			roomsList = new List();
			roomsList.addEventListener(starling.events.Event.CHANGE, changeHandler);
			roomsList.layoutData = new VerticalLayoutData(100, 100);
			roomsList.itemRendererFactory = function ():DefaultListItemRenderer
			{
				var renderer:DefaultListItemRenderer = new DefaultListItemRenderer();
				renderer.isQuickHitAreaEnabled = true;
				renderer.height = 80;
				renderer.iconSourceField = "image";

				renderer.iconLoaderFactory = function ():ImageLoader
				{
					var loader:ImageLoader = new ImageLoader();
					loader.width = loader.height = 50;
					return loader;
				}

				renderer.labelFunction = function (item:Object):String
				{
					return "<b>" + item.name + "</b>" + "\n" + item.description;
				};

				return renderer;
			};
			this.addChild(roomsList);

			this.addEventListener(FeathersEventType.TRANSITION_IN_COMPLETE, transitionComplete);
		}

		private function transitionComplete(event:starling.events.Event):void
		{
			this.removeEventListener(FeathersEventType.TRANSITION_IN_COMPLETE, transitionComplete);
			loadChatRooms();
		}

		private function loadChatRooms():void
		{
			var request:URLRequest = new URLRequest(Constants.FIREBASE_CHATROOMS_URL);

			var loader:URLLoader = new URLLoader();
			loader.addEventListener(flash.events.Event.COMPLETE, chatRoomsLoaded);
			loader.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			loader.load(request);
		}

		private function chatRoomsLoaded(event:flash.events.Event):void
		{
			event.currentTarget.removeEventListener(flash.events.Event.COMPLETE, chatRoomsLoaded);

			//The JSON generated by Firebase contains the id as the node key, we use this function to add it to our Objects

			var rawData:Object = JSON.parse(event.currentTarget.data);
			var roomsArray:Array = new Array();

			for (var parent:String in rawData) {
				var tempObject:Object = new Object();
				tempObject.id = parent;

				for (var child:* in rawData[parent]) {
					tempObject[child] = rawData[parent][child];
				}

				roomsArray.push(tempObject);
				roomsArray.sortOn("internal_id");
				tempObject = null;
			}

			roomsList.dataProvider = new ListCollection(roomsArray);
		}

		private function changeHandler(event:starling.events.Event):void
		{
			if (ProfileManager.isLoggedIn() === false) {
				alert = Alert.show("This feature requires that you are signed in, proceed to Sign In process?", "Sign In Required", new ListCollection(
						[
							{label: "Cancel"},
							{label: "OK"}
						]));

				alert.addEventListener(starling.events.Event.CLOSE, function (event:starling.events.Event, data:Object):void
				{
					if (data.label == "OK") {
						dispatchEventWith(GO_LOGIN);
					} else {
						//Changing the index triggers a CHANGE event, so we temporarily remove it and add it again
						roomsList.removeEventListener(starling.events.Event.CHANGE, changeHandler);
						roomsList.selectedIndex = -1;
						roomsList.addEventListener(starling.events.Event.CHANGE, changeHandler);
					}
				});
			} else {
				getAccessToken();
			}
		}

		private function getAccessToken():void
		{
			var header:URLRequestHeader = new URLRequestHeader("Content-Type", "application/json");

			var myObject:Object = new Object();
			myObject.grant_type = "refresh_token";
			myObject.refresh_token = Main.profile.refreshToken;

			var request:URLRequest = new URLRequest(Constants.FIREBASE_AUTH_TOKEN_URL);
			request.method = URLRequestMethod.POST;
			request.data = JSON.stringify(myObject);
			request.requestHeaders.push(header);

			var loader:URLLoader = new URLLoader();
			loader.addEventListener(flash.events.Event.COMPLETE, accessTokenLoaded);
			loader.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			loader.load(request);
		}

		private function accessTokenLoaded(event:flash.events.Event):void
		{
			event.currentTarget.removeEventListener(flash.events.Event.COMPLETE, accessTokenLoaded);

			var rawData:Object = JSON.parse(event.currentTarget.data);

			//VERY IMPORTANT: Yhis token will be used to authenticate with the Firebase realtime database
			_data.FirebaseAuthToken = rawData.access_token;
			_data.selectedRoom = roomsList.selectedItem;
			this.dispatchEventWith(GO_CHAT);
		}

		private function errorHandler(event:IOErrorEvent):void
		{
			trace(event.currentTarget.data);
		}

		override public function dispose():void
		{
			if (alert) {
				alert.removeFromParent(true);
			}

			super.dispose();
		}

	}
}