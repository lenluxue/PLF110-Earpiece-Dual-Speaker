import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;

/** ColorOS 17 helper. Legacy ColorOS 16 DEX files remain byte-for-byte intact. */
public final class AudioCompat17 {
    private static final String CALLER = "com.termux";
    private static final int MUSIC = 3;

    private static Object call(Class<?> owner, Object target, String name,
            Class<?>[] signature, Object... arguments) throws Exception {
        Method method = owner.getDeclaredMethod(name, signature);
        method.setAccessible(true);
        return method.invoke(target, arguments);
    }

    private static Object service() throws Exception {
        Object binder = Class.forName("android.os.ServiceManager")
                .getMethod("getService", String.class).invoke(null, "audio");
        if (binder == null) throw new IllegalStateException("Audio service unavailable");
        return Class.forName("android.media.IAudioService$Stub")
                .getMethod("asInterface", Class.forName("android.os.IBinder"))
                .invoke(null, binder);
    }

    private static Object device(int type) throws Exception {
        return Class.forName("android.media.AudioDeviceAttributes")
                .getConstructor(int.class, String.class).newInstance(type, "");
    }

    private static Object volumeInfo(Integer index, Integer max) throws Exception {
        Class<?> builderType = Class.forName("android.media.VolumeInfo$Builder");
        Object builder = builderType.getConstructor(int.class).newInstance(MUSIC);
        if (index != null) {
            builderType.getMethod("setMinVolumeIndex", int.class).invoke(builder, 0);
            builderType.getMethod("setMaxVolumeIndex", int.class).invoke(builder, max);
            builderType.getMethod("setVolumeIndex", int.class).invoke(builder, index);
        }
        return builderType.getMethod("build").invoke(builder);
    }

    private static Object getVolume(Object audio, int type) throws Exception {
        return call(Class.forName("android.media.IAudioService"), audio, "getDeviceVolume",
                new Class<?>[]{Class.forName("android.media.VolumeInfo"),
                    Class.forName("android.media.AudioDeviceAttributes"), String.class},
                volumeInfo(null, null), device(type), CALLER);
    }

    private static int volumeField(Object volume, String field) throws Exception {
        return ((Number) volume.getClass().getMethod(field).invoke(volume)).intValue();
    }

    private static void setVolume(int type, int index) throws Exception {
        Object audio = service();
        Object current = getVolume(audio, type);
        int max = volumeField(current, "getMaxVolumeIndex");
        int min = volumeField(current, "getMinVolumeIndex");
        if (index < min || index > max) throw new IllegalArgumentException("Volume outside device range");
        call(Class.forName("android.media.IAudioService"), audio, "setDeviceVolume",
                new Class<?>[]{Class.forName("android.media.VolumeInfo"),
                    Class.forName("android.media.AudioDeviceAttributes"), String.class},
                volumeInfo(index, max), device(type), CALLER);
        System.out.println("setDeviceVolume(device=" + type + ", index=" + index + ") ok");
    }

    private static int mediaStrategy() throws Exception {
        Class<?> strategyType = Class.forName("android.media.audiopolicy.AudioProductStrategy");
        ArrayList<Object> strategies = new ArrayList<>();
        int status = ((Number) call(strategyType, null, "native_list_audio_product_strategies",
                new Class<?>[]{ArrayList.class}, strategies)).intValue();
        if (status != 0) throw new IllegalStateException("Cannot list audio strategies: " + status);
        int result = -1;
        for (Object strategy : strategies) {
            Object attributes = strategyType.getMethod("getAudioAttributesForLegacyStreamType", int.class)
                    .invoke(strategy, MUSIC);
            if (attributes == null) continue;
            int id = ((Number) strategyType.getMethod("getId").invoke(strategy)).intValue();
            if (result != -1 && result != id) throw new IllegalStateException("Ambiguous music strategy");
            result = id;
        }
        if (result < 0) throw new IllegalStateException("No music strategy available");
        return result;
    }

    private static void route(int strategy, String mode) throws Exception {
        String method;
        if ("keep".equals(mode)) method = "setDevicesRoleForStrategy";
        else if ("clear".equals(mode)) method = "removeDevicesRoleForStrategy";
        else throw new IllegalArgumentException("Unknown route mode");
        int status = ((Number) call(Class.forName("android.media.AudioSystem"), null, method,
                new Class<?>[]{int.class, int.class, int[].class, String[].class},
                strategy, 1, new int[]{2, 1}, new String[]{"", ""})).intValue();
        if (status != 0) throw new IllegalStateException(method + " rejected route: " + status);
        System.out.println(method + "(" + strategy + ",1) => " + status);
    }

    private static void run(String[] args) throws Exception {
        if (args.length == 1 && "config".equals(args[0])) {
            int strategy = mediaStrategy();
            int max = volumeField(getVolume(service(), 2), "getMaxVolumeIndex");
            if (max < 1) throw new IllegalStateException("Invalid music volume maximum");
            System.out.println(strategy + " " + max);
        } else if (args.length == 2 && "get".equals(args[0])) {
            System.out.println(volumeField(getVolume(service(), Integer.parseInt(args[1])), "getVolumeIndex"));
        } else if (args.length == 3 && "set".equals(args[0])) {
            setVolume(Integer.parseInt(args[1]), Integer.parseInt(args[2]));
        } else if (args.length == 3 && "route".equals(args[0])) {
            route(Integer.parseInt(args[1]), args[2]);
        } else {
            throw new IllegalArgumentException("config | get DEVICE | set DEVICE INDEX | route STRATEGY keep|clear");
        }
    }

    public static void main(String[] args) {
        try { run(args); }
        catch (Throwable error) {
            if (error instanceof InvocationTargetException && error.getCause() != null) error = error.getCause();
            System.err.println("AudioCompat17: " + error);
            System.exit(1);
        }
    }
}
